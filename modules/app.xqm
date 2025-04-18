xquery version "3.1";

(:~
 : HTML templating functions for populating web views of the public-repo
 :)

module namespace app="http://exist-db.org/xquery/app";

import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm";
import module namespace scanrepo="http://exist-db.org/xquery/admin/scanrepo" at "scan.xqm";
import module namespace versions="http://exist-db.org/apps/public-repo/versions" at "versions.xqm";

import module namespace semver="http://exist-db.org/xquery/semver";
import module namespace templates="http://exist-db.org/xquery/html-templating";

declare namespace request="http://exist-db.org/xquery/request";
declare namespace response="http://exist-db.org/xquery/response";
declare namespace xmldb="http://exist-db.org/xquery/xmldb";


declare variable $app:repo-url := concat(substring-before(request:get-uri(), "public-repo/"), "public-repo/");


(:~
 : Set the base-elements href attribute to a URL that will be used to resolve relative paths
 : since $base-url is set in the controller and cannot have a trailing slash it will be appended here
 :
 : @param $base-url this must be set by the controller for any request that will render a HTML page
 : @returns attribute(href) relative paths will be resolved with its value 
 :)
declare
    %templates:wrap
function app:base-url($node as node(), $model as map(*), $base-url as xs:string) as attribute(href) {
    attribute href { $base-url || "/" }
}; 

(:~
 : Load the package groups document for the admin page's package-groups section
 :)
declare %templates:wrap function app:load-package-groups($node as node(), $model as map(*)) {
    map { 
        "package-groups": 
            for $package-group in doc($config:package-groups-doc)//package-group 
            order by $package-group/abbrev[not(@type)]
            return
                $package-group,
        "dates-published": 
            for $put in collection($config:logs-col)//event[type eq "put-package"]
            group by $package-name := $put/package-name/string()
            return
                map {
                    "package-name": $package-name,
                    "versions": $put ! map { "version": ./package-version/string(), "date-published": ./dateTime cast as xs:dateTime }
                }
    }
};

(:~
 : Load the package title for the admin page's package-groups section
 :)
declare function app:package-group-title($node as node(), $model as map(*)) {
    $model?package-group/title/string()
};

(:~
 : Load the package title for the admin page's package-groups section
 :)
declare function app:package-group-abbrev($node as node(), $model as map(*)) {
    $model?package-group/abbrev/string()
};

(:~
 : Load the package title for the admin page's package-groups section
 :)
declare function app:package-group-name($node as node(), $model as map(*)) {
    $model?package-group/name/string()
};

(:~
 : Load the packages for each package-group
 :)
declare %templates:wrap function app:load-packages($node as node(), $model as map(*)) {
    map { "packages": $model?package-group//package }
};


(:~
 : Load the package version
 :)
declare function app:package-version($node as node(), $model as map(*)) {
    $model?package/version
};

(:~
 : Load the package version
 :)
declare function app:package-requires($node as node(), $model as map(*)) {
    let $requires := $model?package/requires[@processor eq $config:exist-processor-name]
    return
        ($requires/@* except $requires/@processor) ! (./name() || ": " || ./string())
};

(:~
 : Load the package version
 :)
declare function app:package-date-published($node as node(), $model as map(*)) {
    let $date-published := $model?dates-published[?package-name eq $model?package/name]?versions[?version eq $model?package/version]?date-published => head()
    return
        if (exists($date-published)) then
            if (xs:date($date-published) = current-date()) then
                format-dateTime($date-published, "Today [H00]:[m00]:[s00]")
            else
                format-dateTime($date-published, "[M00]/[D00]/[Y0000] [H00]:[m00]:[s00]")
        else
            "- (Predates logging)"
};

(:~
 : Load the get-package logs for the admin section's table
 :)
declare %templates:wrap
function app:load-get-package-logs-for-admin-table ($node as node(), $model as map(*), $top-n as xs:integer) {
    let $package-logs :=
        for $event in collection($config:logs-col)//event[type eq "get-package"]
        group by $package-name := $event/package-name/string()
        let $count := count($event)
        order by $count descending
        return
            map {
                "package-name": $package-name,
                "count": $count
            }

    return
        map {
            "package-logs": subsequence($package-logs, 1, $top-n)
        }
};

(:~
 : Load the package title for the admin section's table
 :)
declare function app:get-package-stats($node as node(), $model as map(*)) {
    $model?package-log?package-name || " (" || $model?package-log?count || ")"
};

(:~
 : Rebuild the package-groups metadata
 :)
declare function app:rebuild-package-groups-metadata($node as node(), $model as map(*), $rebuild-package-groups-metadata as xs:boolean?) {
    if ($rebuild-package-groups-metadata) then
        let $_ := scanrepo:rebuild-package-groups()
        return
            <p class="success">The package-groups metadata has been rebuilt.</p>
    else
        ()
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
    return (
        if (count($package-groups) eq 1) then (
        ) else
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
                        app:redirect-to($info-url)
                (: view current package info :)
                else
                    let $packages := $package-group//package
                    let $compatible-packages := versions:get-packages-satisfying-exist-version($packages, $procVersion)
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
                            <li class="package text-warning">The package with convenient short name <code>{$abbrev}</code> and with unique package name 
                                <code>{$package-group/name}</code> is not compatible with eXist {$procVersion} and requires a newer version of eXist.</li>
        return
            if (exists($listing)) then (
                $listing
            ) else (
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
    let $repoURL := $app:repo-url
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
    let $title := $package-group/title/string()
    let $path := $newest-package/@path
    let $requires := $newest-package/requires
    let $download-url := concat($repoURL, "public/", $path)
    let $required-exist-version := $requires[@processor eq $config:exist-processor-name]/(@version, @semver-min)[1]
    let $info-url :=
        concat($repoURL, "packages/", $package-group/abbrev[not(@type eq "legacy")],
            if ($required-exist-version) then
                concat("?eXist-db-min-version=", $required-exist-version)
            else
                ()
        )

    return
        <li class="package {$newest-package/type}">
            {app:package-type-icon($newest-package/type)}
            <a href="{$info-url}" class="package-icon-area"><img class="appIcon" src="{$icon}" /></a>
            <div class="package-info">
            {
                if (not($show-details)) then (
                    app:short-package-summary($title, $newest-package, $requires, $download-url, $info-url)
                ) else (
                    <h2><a href="{$info-url}">{$title}</a></h2>,
                    if (empty($newest-package)) then (
                        <p>No versions of {string-join($package-group/abbrev, " or ")} found that are compatible with eXist-db {$procVersion}+.</p>
                    ) else (
                        <table>
                            <tr>
                                <th>Description:</th>
                                <td>{ $newest-package/description/string() }</td>
                            </tr>
                            <tr>
                                <th>Version:</th>
                                <td>{ $newest-package/version/string() }</td>
                            </tr>
                            <tr>
                                <th>Size:</th>
                                <td>{ $newest-package/@size idiv 1024 }k</td>
                            </tr>
                            {
                                if (empty($newest-package/requires)) then (
                                ) else (
                                    <tr>
                                        <th class="requires">Requirement:</th>
                                        <td>eXist-db { if ($requires) then app:requires-to-english($requires) else () }</td>
                                    </tr>
                                )
                            }
                            <tr>
                                <th>Package Abbrev:</th>
                                <td>{ $newest-package/abbrev[not(@type)]/string() }</td>
                            </tr>
                            <tr>
                                <th>Package Name:</th>
                                <td>{ $newest-package/name/string() }</td>
                            </tr>
                            <tr>
                                <th>Author(s):</th>
                                <td>{string-join($newest-package/author, ", ")}</td>
                            </tr>
                            <tr>
                                <th>License:</th>
                                <td>{ $newest-package/license/string() }</td>
                            </tr>
                            {
                                if ($newest-package/website eq "") then (
                                ) else (
                                    <tr>
                                        <th>Website:</th>
                                        <td><a href="{$newest-package/website}">{ $newest-package/website/string() }</a></td>
                                    </tr>
                                )
                            }
                            <tr>
                                <th>Download:</th>
                                <td><a href="{$download-url}" title="click to download package">{$path/string()}</a></td>
                            </tr>
                        </table>
                    )
                    ,
                    if (empty(($older-packages, $incompatible-packages))) then (
                    ) else (
                        <div class="other-versions">
                            <h3>Download other versions:</h3>
                            <ul class="compatible">
                            {
                                (: show links to older versions of the package that are compatible with the requested version of eXist :)
                                for $package in $older-packages
                                let $download-version-url := concat($repoURL, "public/", $package/@path)
                                return
                                    <li>
                                        <a href="{$download-version-url}">{ $package/version/string() }</a>
                                    </li>
                            }
                            </ul>
                            <ul class="incompatbile">
                            {
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
                                        <a href="{$download-version-url}">{ $package/version/string() }</a>
                                        {
                                            " (Note: Requires eXist-db "
                                            || app:requires-to-english($requires)
                                            || (
                                                if ($package/abbrev ne $package-group/abbrev[not(@type = "legacy")]) then 
                                                    (". This version's short title is “" || $package/abbrev || "”") 
                                                else 
                                                    ()
                                                )
                                            || ".)"
                                        }
                                    </li>
                            }
                            </ul>
                        </div>
                    )
                    ,
                    if (empty($newest-package/changelog/change)) then (
                    ) else (
                        <div class="changelog">
                            <h3>Change log:</h3>
                            <table class="table">
                            {
                                for $change in $newest-package/changelog/change
                                let $version := $change/@version/string()
                                let $comment := $change/node()
                                order by $version descending collation "http://www.w3.org/2013/collation/UCA?numeric=yes"
                                return
                                    <tr class="changelog-row">
                                        <th>{$version}</th>
                                        <td>{$comment}</td>
                                    </tr>
                            }
                            </table>
                        </div>
                    )
                )
        }
        </div>
    </li>
};

declare function app:package-type-icon ($type as xs:string?) as element(img)? {
    switch ($type)
        case ("application") return
            <img src="{$app:repo-url || "resources/images/app.gif"}" class="ribbon" alt="application" title="This is an application"/>
        case ("library") return
            <img src="{$app:repo-url || "resources/images/library.gif"}" class="ribbon" alt="library" title="This is a library"/>
        case ("plugin") return
            <img src="{$app:repo-url || "resources/images/plugin.gif"}" class="ribbon" alt="plugin" title="This is a plugin"/>
        default return ()
};

declare function app:short-package-summary($title as xs:string, $package as element(), $requires as element(), $download-url as xs:string, $info-url as xs:string) as element()+ {
    <h3 class="package-title"><a href="{$info-url}">{$title}</a></h3>,
    <p class="package-description">{$package/description/string()}</p>,
    <div class="mb-4">
        <a class="icon-link" href="{$download-url}">
            Download Version {$package/version/string()}
        </a>
        or
        <a class="icon-link icon-link-hover" href="{$info-url}">
            Read More Information
            <svg xmlns="http://www.w3.org/2000/svg" class="bi" viewBox="0 0 16 16" aria-hidden="true">  
                <path d="M1 8a.5.5 0 0 1 .5-.5h11.793l-3.147-3.146a.5.5 0 0 1 .708-.708l4 4a.5.5 0 0 1 0 .708l-4 4a.5.5 0 0 1-.708-.708L13.293 8.5H1.5A.5.5 0 0 1 1 8z"/>
            </svg>
        </a>
    </div>
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
    else if ($requires/@semver-min and $requires/@semver-max) then
        concat(
            " version ", 
            if (semver:validate-expath-package-semver-template($requires/@semver-min)) then
                semver:serialize-parsed(semver:resolve-expath-package-semver-template-min($requires/@semver-min))
            else
                $requires/@semver-min,
            " or later, and ", 
            if (semver:validate-expath-package-semver-template($requires/@semver-max)) then
                concat("earlier than ", semver:serialize-parsed(semver:resolve-expath-package-semver-template-max($requires/@semver-max)))
            else
                $requires/@semver-max || " or earlier"
        )
    else if ($requires/@semver-min) then
        concat(
            " version ", 
            if (semver:validate-expath-package-semver-template($requires/@semver-min)) then
                semver:serialize-parsed(semver:resolve-expath-package-semver-template-min($requires/@semver-min))
            else
                $requires/@semver-min, 
            " or later"
        )
    else if ($requires/@semver-max) then
        concat(
            " version ", 
            if (semver:validate-expath-package-semver-template($requires/@semver-max)) then
                concat("earlier than ", semver:serialize-parsed(semver:resolve-expath-package-semver-template-max($requires/@semver-max)))
            else
                $requires/@semver-min || " or earlier"
        )
    else
        " version " || $config:default-exist-version
};

(:~
 : helper function to work around a bug in response:redirect-to#1
 : see https://github.com/eXist-db/exist/issues/4249
 :)
declare function app:redirect-to ($location as xs:string) {
    response:set-status-code(302),
    response:set-header("Location", $location)
};
