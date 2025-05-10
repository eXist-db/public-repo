xquery version "3.1";

(:~
 : HTML templating functions for populating web views of the public-repo
 :)

module namespace app="http://exist-db.org/xquery/app";

import module namespace semver="http://exist-db.org/xquery/semver";
import module namespace templates="http://exist-db.org/xquery/html-templating";

import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm";
import module namespace redirect="http://exist-db.org/xquery/lib/redirect" at "redirect.xqm";
import module namespace scanrepo="http://exist-db.org/xquery/admin/scanrepo" at "scan.xqm";
import module namespace versions="http://exist-db.org/apps/public-repo/versions" at "versions.xqm";
import module namespace packages="http://exist-db.org/apps/public-repo/packages" at "packages.xqm";

declare namespace request="http://exist-db.org/xquery/request";
declare namespace response="http://exist-db.org/xquery/response";
declare namespace xmldb="http://exist-db.org/xquery/xmldb";

(: TODO shouldn't we get $repoURL from $config? - joewiz :)
declare variable $app:repo-url := concat(substring-before(request:get-uri(), "public-repo/"), "public-repo/");

declare variable $app:settings := doc($config:app-data-col || '/' || $config:settings-doc-name)/settings;

declare
    %templates:wrap
function app:title($node as node(), $model as map(*)) as xs:string? {
    $app:settings/title/string()
}; 

declare
    %templates:wrap
function app:description($node as node(), $model as map(*)) as xs:string? {
    $app:settings/description/text()
};

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

declare
    %templates:replace
function app:search-package ($node as node(), $model as map(*), $q as xs:string?) as element() {
    if (empty($q) or string-length($q) eq 0) then (
        <p>Enter a search term in the input above.</p>
    ) else (
        let $results := packages:search($q)
        
        return
            if (count($results) = 0) then (
                <p>The search for <strong>{$q}</strong> yielded no results.</p>
            ) else (
                <ul class="package-list">{
                    for $package-group in $results
                    return packages:render-list-item($package-group, <li />)
                }</ul>
            )
    )
};

declare
    %templates:replace
function app:show-top-nav-search ($node as node(), $model as map(*)) as element()? {
    (: if ($model?show-top-nav-search) then ( :)
    if ($model?('show-top-nav-search')) then (
        $node
    ) else (
        <span>{
            $model?('show-top-nav-search'),
            request:get-parameter("top-nav-search", "no")
        }</span>
    )
};

(:~
 : Load the package groups document for the admin page's package-groups section
 :)
declare %templates:wrap
function app:load-package-groups($node as node(), $model as map(*)) {
    map { 
        "package-groups": 
            for $package-group in doc($config:package-groups-doc)//package-group 
            order by $package-group/abbrev[not(@type)]
            return
                $package-group
        ,
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
function app:top-download-stats ($node as node(), $model as map(*), $top-n as xs:integer) as map(*) {
    packages:download-stats($top-n)
};

(:~
 : Load the package title for the admin section's table
 :)
declare %templates:wrap
function app:package-stats-item($node as node(), $model as map(*)) {
    doc($config:package-groups-doc)//package-group[name = $model?package-log?package-name]
    => packages:render-list-item($node)
};

declare
    %templates:wrap
function app:package-stats-download($node as node(), $model as map(*)) {
    $model?package-log?count
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
declare function app:list-packages($node as node(), $model as map(*)) as element(li)* {
    packages:list-all()
};

(:~
 : Single package group view - show the full version of this package group
 :
 : Package is found via the abbrev URL parameter, with an optional eXist version parameter.
 : If the eXist version parameter is missing, eXist 2.2.0 is assumed (see config.xqm).
 :)
declare function app:view-package($node as node(), $model as map(*)) {
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
                    let $repoURL := $app:repo-url
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
                        redirect:permanent($info-url)
                (: view current package info :)
                else
                    let $packages := $package-group//package
                    let $compatible-packages := versions:get-packages-satisfying-exist-version($packages, $procVersion)
                    let $incompatible-packages := $packages except $compatible-packages
                    return
                        if ($compatible-packages or $incompatible-packages) then
                            let $trimmed-package-group := 
                                element package-group { 
                                    $package-group/(title, name, abbrev),
                                    $compatible-packages
                                }
                            return
                                packages:render-group-detail($trimmed-package-group, $incompatible-packages, $procVersion)
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

declare
    %templates:replace
function app:featured-packages ($node as node(), $model as map(*)) as element(div)? {
    if (empty($app:settings//featured)) then (
    ) else (
        <div>{$node/@*}
            <h2>Featured Packages</h2>
            <ul class="package-list">{
                let $featured := $app:settings//featured/string()[. ne '']
                let $package-groups := doc($config:package-groups-doc)//package-group[abbrev = $featured]
                return $package-groups ! packages:render-list-item(., <li/>)
            }
            </ul>
        </div>
    )
};
