xquery version "3.1";

(:~
 : Templating functions for the public-repo web views, called from templates/*.html.
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

(:~
 : The app's URL path up to and including "public-repo/", from the request URI.
 :)
(: TODO shouldn't we get $repoURL from $config? - joewiz :)
declare variable $app:repo-url := concat(substring-before(request:get-uri(), "public-repo/"), "public-repo/");

(:~
 : The repository settings element.
 :)
declare variable $app:settings := doc($config:app-data-col || '/' || $config:settings-doc-name)/settings;

(:~
 : The repository title from the settings.
 :
 : @param $node the template node
 : @param $model the template model
 : @return the title, if configured
 :)
declare
    %templates:wrap
function app:title($node as node(), $model as map(*)) as xs:string? {
    $app:settings/title/string()
}; 

(:~
 : The repository description from the settings.
 :
 : @param $node the template node
 : @param $model the template model
 : @return the description, if configured
 :)
declare
    %templates:wrap
function app:description($node as node(), $model as map(*)) as xs:string? {
    $app:settings/description/text()
};

(:~
 : Set the base element's href to $base-url with a trailing slash.
 :
 : @param $node the template node
 : @param $model the template model
 : @param $base-url the app's base URL without trailing slash, set by the controller
 : @return the href attribute
 :)
declare
    %templates:wrap
function app:base-url($node as node(), $model as map(*), $base-url as xs:string) as attribute(href) {
    attribute href { $base-url || "/" }
}; 

(:~
 : Search the package groups and render the results.
 :
 : @param $node the template node
 : @param $model the template model
 : @param $q the search term
 : @return a list of matching package groups, or a message if $q is empty or nothing matched
 :)
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

(:~
 : Show the top navigation search form if ?show-top-nav-search is true.
 :
 : @param $node the template node
 : @param $model the template model
 : @return the form, or the empty sequence
 :)
declare %templates:replace
function app:show-top-nav-search ($node as node(), $model as map(*)) as element()? {
    if ($model?('show-top-nav-search')) then ($node) else ()
};

(:~
 : Load the package groups and their publication dates for the admin page.
 :
 : @param $node the template node
 : @param $model the template model
 : @return a map with ?package-groups, ordered by abbrev, and ?dates-published,
 :   the versions and publication dates per package name from the put-package log
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
 : The title of the current package group.
 :
 : @param $node the template node
 : @param $model the template model, with ?package-group
 : @return the title
 :)
declare function app:package-group-title($node as node(), $model as map(*)) {
    $model?package-group/title/string()
};

(:~
 : The abbrevs of the current package group, current and legacy.
 :
 : @param $node the template node
 : @param $model the template model, with ?package-group
 : @return the abbrevs
 :)
declare function app:package-group-abbrev($node as node(), $model as map(*)) {
    $model?package-group/abbrev/string()
};

(:~
 : The unique name of the current package group.
 :
 : @param $node the template node
 : @param $model the template model, with ?package-group
 : @return the name
 :)
declare function app:package-group-name($node as node(), $model as map(*)) {
    $model?package-group/name/string()
};

(:~
 : Load the packages of the current package group.
 :
 : @param $node the template node
 : @param $model the template model, with ?package-group
 : @return a map with ?packages
 :)
declare %templates:wrap function app:load-packages($node as node(), $model as map(*)) {
    map { "packages": $model?package-group//package }
};


(:~
 : The version of the current package.
 :
 : @param $node the template node
 : @param $model the template model, with ?package
 : @return the version element
 :)
declare function app:package-version($node as node(), $model as map(*)) {
    $model?package/version
};

(:~
 : The eXist-db version requirements of the current package.
 :
 : @param $node the template node
 : @param $model the template model, with ?package
 : @return one "name: value" string per requirement, e.g. "semver-min: 5.0.0"
 :)
declare function app:package-requires($node as node(), $model as map(*)) {
    let $requires := $model?package/requires[@processor eq $config:exist-processor-name]
    return
        ($requires/@* except $requires/@processor) ! (./name() || ": " || ./string())
};

(:~
 : When the current package version was published.
 :
 : @param $node the template node
 : @param $model the template model, with ?package and ?dates-published
 : @return "MM/DD/YYYY HH:MM:SS", "Today HH:MM:SS", or "- (Predates logging)"
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
 : Load the download counts of the most downloaded packages.
 :
 : @param $node the template node
 : @param $model the template model
 : @param $top-n the number of packages
 : @return a map with ?package-logs, one map per package with its name and count, most downloaded first
 :)
declare %templates:wrap
function app:top-download-stats ($node as node(), $model as map(*), $top-n as xs:integer) as map(*) {
    packages:download-stats($top-n)
};

(:~
 : Render the package group of the current download stats entry.
 :
 : @param $node the template node, the list item to render into
 : @param $model the template model, with ?package-log
 : @return the rendered list item
 :)
declare %templates:wrap
function app:package-stats-item($node as node(), $model as map(*)) {
    doc($config:package-groups-doc)//package-group[name = $model?package-log?package-name]
    => packages:render-list-item($node)
};

(:~
 : The download count of the current download stats entry.
 :
 : @param $node the template node
 : @param $model the template model, with ?package-log
 : @return the download count
 :)
declare
    %templates:wrap
function app:package-stats-download($node as node(), $model as map(*)) {
    $model?package-log?count
};

(:~
 : Rebuild the package-groups metadata, if requested.
 :
 : @param $node the template node
 : @param $model the template model
 : @param $rebuild-package-groups-metadata true to rebuild
 : @return a success message, or the empty sequence
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
 : List all package groups on the landing page.
 :
 : @param $node the template node
 : @param $model the template model
 : @return one list item per package group
 :)
declare function app:list-packages($node as node(), $model as map(*)) as element(li)* {
    packages:list-all()
};

(:~
 : Show the package group with the requested abbrev.
 :
 : Only the packages compatible with the eXist-db-min-version request parameter
 : (default $config:default-exist-version) are shown in full. A legacy abbrev
 : redirects to the current one. If several package groups share the abbrev,
 : their names are listed first.
 :
 : @param $node the template node
 : @param $model the template model
 : @return the rendered package groups, or a message with status 404
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

(:~
 : Load the download counts per client type.
 :
 : @param $node the template node
 : @param $model the template model
 : @return a map with ?client-stats, one map per client type with its count, most downloads first
 :)
declare %templates:wrap
function app:client-type-stats($node as node(), $model as map(*)) as map(*) {
    let $client-stats :=
        for $event in collection($config:logs-col)//event[type eq "get-package"]
        group by $client-type := ($event/client-type/string(), "unknown")[1]
        let $count := count($event)
        order by $count descending
        return
            map {
                "client-type": $client-type,
                "count": $count
            }
    return
        map { "client-stats": $client-stats }
};

(:~
 : The client type of the current client stats entry.
 :
 : @param $node the template node
 : @param $model the template model, with ?client-stat
 : @return the client type
 :)
declare %templates:wrap
function app:client-stat-type($node as node(), $model as map(*)) {
    $model?client-stat?client-type
};

(:~
 : The download count of the current client stats entry.
 :
 : @param $node the template node
 : @param $model the template model, with ?client-stat
 : @return the download count
 :)
declare %templates:wrap
function app:client-stat-count($node as node(), $model as map(*)) {
    $model?client-stat?count
};

(:~
 : Render the featured packages listed in the settings.
 :
 : @param $node the template node, whose attributes are copied to the result
 : @param $model the template model
 : @return the featured package groups, or the empty sequence if there are none
 :)
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
