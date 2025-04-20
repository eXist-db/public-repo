xquery version "3.1";

module namespace packages="http://exist-db.org/apps/public-repo/packages";

import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm";
import module namespace versions="http://exist-db.org/apps/public-repo/versions" at "versions.xqm";

declare variable $packages:repo-url := concat(substring-before(request:get-uri(), "public-repo/"), "public-repo/");

declare
function packages:search ($query as xs:string) as element(package-group)* {
    filter(
        doc($config:package-groups-doc)//package-group,
        function ($pkg) {
            $pkg[abbrev[not(@type)][contains(., $query)]]
            or $pkg[contains(name, $query)]
        }
    )
};

(:~
 : Landing page - show the compact version of all package groups
 : 
 :)
declare
function packages:list-all() as element(li)* {
    for $package-group in doc($config:package-groups-doc)//package-group
    order by lower-case($package-group/title)
    return
        packages:render-list-item($package-group)
};

(:~
 : Used by all HTML listings of packages - landing page views of all packages and interior views of individual package groups
 :)
declare function packages:render-list-item($package-group as element(package-group)) as element(li) {
    let $repoURL := $packages:repo-url
    let $title := $package-group/title/string()
    let $package := head($package-group//package)
    let $icon :=
        if ($package/icon and $package/@status) then
            $package/icon[1]
        else if ($package/icon) then
            $repoURL || "public/" || $package/icon[1]
        else
            $repoURL || "resources/images/package.png"

    let $path := $package/@path
    let $requires := $package/requires

    let $download-url := concat($repoURL, "public/", $path)

    let $required-exist-version := $requires[@processor eq $config:exist-processor-name]/(@version, @semver-min)[1]
    let $info-url :=
        concat(
            $repoURL, "packages/",
            $package-group/abbrev[not(@type eq "legacy")],
            if ($required-exist-version) then (
                "?eXist-db-min-version=" || $required-exist-version
            ) else (
            )
        )

    return
        <li class="package {$package/type}">
            <a href="{$info-url}" class="package-icon-area"><img class="app-icon" src="{$icon}" /></a>
            <div class="package-info">
                <h3 class="package-title"><a href="{$info-url}">{$title}</a></h3>
                <p class="package-description">{$package/description/string()}</p>
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
            </div>
        </li>
};


(:~
 : Used by all HTML listings of packages - landing page views of all packages and interior views of individual package groups
 :)
declare function packages:render-group-detail(
    $package-group as element(package-group),
    $incompatible-packages as element(package)*,
    $procVersion as xs:string?
) as element(li) {
    (: TODO shouldn't we get $repoURL from $config? - joewiz :)
    let $repoURL := $packages:repo-url
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
        <article class="package package-detail {$newest-package/type}">
            <div class="package-icon-area"><img class="app-icon" src="{$icon}" /></div>
            <div class="package-info">
                <h2>{$title}</h2>
                {
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
                                        <td>eXist-db { if ($requires) then versions:requires-to-english($requires, $config:default-exist-version) else () }</td>
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
                                            || versions:requires-to-english($requires, $config:default-exist-version)
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
                }
            </div>
        </article>
};

declare function packages:download-stats ($top-n as xs:integer) as map(*) {
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
