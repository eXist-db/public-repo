xquery version "3.1";

(:~
 : HTML templating functions for populating web views of the public-repo
 :)

module namespace app="http://exist-db.org/xquery/app";

import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm";
import module namespace versions="http://exist-db.org/apps/public-repo/versions" at "versions.xqm";

declare namespace request="http://exist-db.org/xquery/request";
declare namespace response="http://exist-db.org/xquery/response";

declare function app:abs-path-to-apps-xml($node as node(), $model as map(*), $mode as xs:string?) {
    let $url := request:get-parameter("app-root-absolute-url", ()) || "/public/apps.xml"
    return
        <a href="{$url}">{$url}</a>
};

(:~
 : Landing page - show the compact version of all package groups
 :)
declare function app:list-packages($node as node(), $model as map(*), $mode as xs:string?) {
    for $package-group in doc($config:package-groups-doc)//package-group
    let $show-details := false()
    order by lower-case($package-group/title)
    return
        app:package-group-to-list-item($package-group, (), (), $show-details)
};

(:~
 : Single package group view - show the full version of this package group
 :
 : Package is found via the abbrev URL parameter, with an optional eXist version parameter.
 : If the eXist version parameter is missing, eXist 2.2.0 is assumed (see config.xqm).
 :)
declare function app:view-package($node as node(), $model as map(*), $mode as xs:string?) {
    let $abbrev := request:get-parameter("abbrev", ())
    let $procVersion := request:get-parameter("eXist-db-min-version", $config:default-exist-version)
    let $package-groups := doc($config:package-groups-doc)//package-group[abbrev eq $abbrev]
    return
        (
            if (count($package-groups) gt 1) then 
                <p>More than one package matches the requested convenient short 
                    name, <code>{$abbrev}</code>. The unique package names that 
                    match this short name are: 
                    <ol>
                        {
                            for $package-group in $package-groups
                            let $name := $package-group/name
                            order by $name
                            return
                                <li><code>{$name/string()}</code></li>
                        }
                    </ol>
                    The packages with versions available that are compatible with eXist {$procVersion} or higher are as follows:
                </p>
            else 
                ()
            ,
    let $listing := 
        for $package-group in $package-groups
        return
            (: catch requests for a package using its legacy "abbrev" and redirect
             : them to a URL using the app's current abbrev, to encourage use of the
             : current abbrev :)
            if ($package-group/abbrev[. eq $abbrev]/@type eq "legacy") then
                let $current-abbrev := $package-group/abbrev[not(@type eq "legacy")]
                (: TODO shouldn't we get $repoURL from $config? - joewiz :)
                let $repoURL := concat(substring-before(request:get-uri(), "public-repo/"), "public-repo/")
                let $newest-compatible-package := head($package-group//package[abbrev eq $abbrev])
                let $required-exist-version := $newest-compatible-package/requires[@processor eq $config:exist-processor-name]/(@version, @semver-min)[1]
                let $info-url :=
                    concat($repoURL, "packages/", $current-abbrev, ".html",
                        if ($required-exist-version) then
                            concat("?eXist-db-min-version=", $required-exist-version)
                        else
                            ()
                    )
                return
                    response:redirect-to(xs:anyURI($info-url))
            (: view current package info :)
            else
                let $packages := $package-group//package
                let $compatible-packages := versions:find-compatible-packages($packages, $procVersion)
                let $incompatible-packages := $packages except $compatible-packages
                let $show-details := true()
                return
                    if ($compatible-packages or $incompatible-packages) then
                        let $trimmed-package-group := 
                            element package-group { 
                                $package-group/(title, name, abbrev),
                                $compatible-packages
                            }
                        return
                            app:package-group-to-list-item($trimmed-package-group, $incompatible-packages, $procVersion, $show-details)
                    else
                        <li class="package text-warning">The package with convenient short name <code>{$abbrev}</code> and with unique package name <code>{$package-group/name}</code> is not compatible with eXist {$procVersion} and requires a newer version of eXist.</li>
    return
        if (exists($listing)) then
            $listing
        else
            (
                response:set-status-code(404),
                <li class="package text-warning">No package {$abbrev} is available.</li>
            )
    )
};

(:~
 : Used by all HTML listings of packages - landing page views of all packages and interior views of individual package groups
 :)
declare function app:package-group-to-list-item($package-group as element(package-group), $incompatible-packages as element(package)*, $procVersion as xs:string?, $show-details as xs:boolean) {
    (: TODO shouldn't we get $repoURL from $config? - joewiz :)
    let $repoURL := concat(substring-before(request:get-uri(), "public-repo/"), "public-repo/")
    let $packages := $package-group//package
    let $newest-package := head($packages)
    let $older-packages := tail($packages)
    let $icon :=
        if ($newest-package/icon) then
            if ($newest-package/@status) then
                $newest-package/icon[1]
            else
                $repoURL || "public/" || $newest-package/icon[1]
        else
            $repoURL || "resources/images/package.png"
    let $path := $newest-package/@path
    let $requires := $newest-package/requires
    let $download-url := concat($repoURL, "public/", $path)
    let $required-exist-version := $requires[@processor eq $config:exist-processor-name]/(@version, @semver-min)[1]
    let $info-url :=
        concat($repoURL, "packages/", $package-group/abbrev[not(@type eq "legacy")], ".html",
            if ($required-exist-version) then
                concat("?eXist-db-min-version=", $required-exist-version)
            else
                ()
        )
    return
        <li class="package {$newest-package/type}">
            <div class="packageIconArea">
                <a href="{$info-url}"><img class="appIcon" src="{$icon}"/></a>
            </div>
            {
                switch ($newest-package/type)
                    case ("application") return
                        <img src="{$repoURL || "resources/images/app.gif"}" class="ribbon" alt="application" title="This is an application"/>
                    case ("library") return
                        <img src="{$repoURL || "resources/images/library.gif"}" class="ribbon" alt="library" title="This is a library"/>
                    case ("plugin") return
                        <img src="{$repoURL || "resources/images/plugin.gif"}" class="ribbon" alt="plugin" title="This is a plugin"/>
                    default return ()
            }
            <h3 style="padding-bottom: 0"><a href="{$info-url}">{$package-group/title/string()}</a></h3>
            {
                if ($show-details) then
                    <table>
                        { 
                            if ($newest-package) then 
                                (
                                    <tr>
                                        <th>Description:</th>
                                        <td>{ $newest-package/description/string() }</td>
                                    </tr>,
                                    <tr>
                                        <th>Version:</th>
                                        <td>{ $newest-package/version/string() }</td>
                                    </tr>,
                                    <tr>
                                        <th>Size:</th>
                                        <td>{ $newest-package/@size idiv 1024 }k</td>
                                    </tr>,
                                    if ($newest-package/requires) then
                                        <tr>
                                            <th class="requires">Requirement:</th>
                                            <td>eXist-db { if ($requires) then app:requires-to-english($requires) else () }</td>
                                        </tr>
                                    else
                                        (),
                                    <tr>
                                        <th>Short Title:</th>
                                        <td>{ $newest-package/abbrev[not(@type)]/string() }</td>
                                    </tr>,
                                    <tr>
                                        <th>Package Name (URI):</th>
                                        <td>{ $newest-package/name/string() }</td>
                                    </tr>,
                                    <tr>
                                        <th>Author(s):</th>
                                        <td>{string-join($newest-package/author, ", ")}</td>
                                    </tr>,
                                    <tr>
                                        <th>License:</th>
                                        <td>{ $newest-package/license/string() }</td>
                                    </tr>,
                                    if ($newest-package/website != "") then
                                        <tr>
                                            <th>Website:</th>
                                            <td><a href="{$newest-package/website}">{ $newest-package/website/string() }</a></td>
                                        </tr>
                                    else
                                        (),
                                    <tr>
                                        <th>Download:</th>
                                        <td><a href="{$download-url}" title="click to download package">{$path/string()}</a></td>
                                    </tr>
                                )
                            else
                                <p>No versions of {string-join($package-group/abbrev, " or ")} found that are compatible with eXist-db {$procVersion}+.</p>
                        }
                        {
                            if ($older-packages or $incompatible-packages) then
                                <tr>
                                    <th>Download other versions:</th>
                                    <td>
                                        <ul>{
                                            (: show links to older versions of the package that are compatible with the requested version of eXist :)
                                            for $package in reverse($older-packages)
                                            let $download-version-url := concat($repoURL, "public/", $package/@path)
                                            return
                                                <li>
                                                    <a href="{$download-version-url}">{$package/version/string()}</a>
                                                </li>,
                                                
                                            (: show links to any other version of the package that is compatible with the requested version of eXist, 
                                               but show the requirement that isn't met. use case: crypto library, whose abbrev has changed and whose 
                                               eXist requirements changed in odd ways. for example: 
                                                   - 1. crypto@1.0.0 requires eXist-db 5.0.0-RC8+
                                                   - 2. expath-crypto-exist-lib@5.3.0 requires eXist-db 4.4.0+
                                                   - 3. both versions share the same package name: http://expath.org/ns/crypto. 
                                                   - so based on package version, #2 is the newest package
                                                   - but based on eXist version, #1 is more compatible with eXist 5.x
                                                   - a messy situation, but it's better to show this info than hide packages from view
                                            :)
                                            for $package in $incompatible-packages
                                            let $download-version-url := concat($repoURL, "public/", $package/@path)
                                            let $requires := $package/requires
                                            return
                                                <li>
                                                    <a href="{$download-version-url}">{ $package/version }</a>
                                                    {
                                                        " (Note: Requires eXist-db "
                                                        || app:requires-to-english($requires)
                                                        || 
                                                            (
                                                                if ($package/abbrev ne $package-group/abbrev[not(@type = "legacy")]) then 
                                                                    (". This version's short title is “" || $package/abbrev || "”") 
                                                                else 
                                                                    ()
                                                            )
                                                        || ".)"
                                                    }
                                                </li>
                                        }</ul>
                                    </td>
                                </tr>
                            else ()
                        }
                        {
                            if (exists($newest-package/changelog/change)) then
                                (
                                <tr>
                                    <th colspan="2">Change log:</th>
                                </tr>
                                ,
                                for $change in $newest-package/changelog/change
                                let $version := $change/@version/string()
                                let $comment := $change/node()
                                order by $version descending
                                return
                                    <tr>
                                        <td>{$version}</td>
                                        <td>{$comment}</td>
                                    </tr>
                                )
                            else ()
                        }
                    </table>
                else 
                    <p> 
                        {$newest-package/description/string()}
                        <br/>
                        Version {$newest-package/version} {
                            if ($requires) then
                                concat(" (Requires eXist-db ", app:requires-to-english($requires), ".)")
                            else
                                ()
                            }
                        <br/>
                        Read <a href="{$info-url}">more information</a>, or download <a href="{$download-url}" title="click to download package">{$newest-package/@path/string()}</a>.
                    </p>
            }
        </li>
};

(:~
 : Express eXist version requirements in human readable form
 :)
declare function app:requires-to-english($requires as element()) {
    (: we assume @processor="http://exist.db-org/" :)
    if ($requires/@version) then
        concat(" version ", $requires/@version)
    else if ($requires/@semver) then
        concat(" version ", $requires/@semver)
    else if ($requires/@semver-min) then
        concat(" version ", $requires/@semver-min, " or later")
    else if ($requires/@semver-max) then
        concat(" version ", $requires/@semver-max, " or earlier")
    else
        " version " || $config:default-exist-version
};
