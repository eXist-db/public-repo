xquery version "3.1";

(:~
 : Filter all package groups, returning a list of only the compatible versions.
 :
 : The format of the results preserves compatibility with the package-repo v1.x API.
 : Supports content negotiation: returns JSON when Accept: application/json is sent (#116).
 :)

import module namespace semver="http://exist-db.org/xquery/semver";

import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm";
import module namespace scanrepo="http://exist-db.org/xquery/admin/scanrepo" at "scan.xqm";
import module namespace versions="http://exist-db.org/apps/public-repo/versions" at "versions.xqm";

declare namespace expath="http://expath.org/ns/pkg";
declare namespace request="http://exist-db.org/xquery/request";
declare namespace response="http://exist-db.org/xquery/response";
declare namespace xmldb="http://exist-db.org/xquery/xmldb";

declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

declare option output:method "xml";
declare option output:media-type "application/xml";

declare function local:prefers-json() as xs:boolean {
    let $accept := request:get-header("Accept")
    return
        contains($accept, "application/json")
        and (
            not(contains($accept, "application/xml"))
            or string-length(substring-before($accept, "application/json")) lt string-length(substring-before($accept, "application/xml"))
        )
};

let $exist-version := request:get-parameter("version", $config:default-exist-version)
let $exist-version-semver := semver:parse($exist-version, true()) => semver:serialize-parsed()

(: HTTP caching: use package-groups.xml last-modified as ETag source :)
let $last-modified := xmldb:last-modified($config:metadata-col, $config:package-groups-doc-name)
let $etag := '"' || string($last-modified) || "-" || $exist-version-semver || '"'
let $if-none-match := request:get-header("If-None-Match")
return
    if ($if-none-match eq $etag) then (
        response:set-status-code(304),
        response:set-header("ETag", $etag)
    ) else (
    response:set-header("ETag", $etag),
    response:set-header("Last-Modified", format-dateTime($last-modified, "[FNn,3-3], [D01] [MNn,3-3] [Y0001] [H01]:[m01]:[s01] GMT")),
    let $compatible-apps :=
        for $package-group in doc($config:package-groups-doc)//package-group
        let $compatible-packages := versions:get-packages-satisfying-exist-version($package-group//package, $exist-version-semver)
        where exists($compatible-packages)
        let $newest-package := head($compatible-packages)
        let $older-packages := tail($compatible-packages)
        return
            map {
                "newest": $newest-package,
                "older": $older-packages
            }
    return
        if (local:prefers-json()) then (
            response:set-header("Content-Type", "application/json"),
            serialize(
                map {
                    "version": $exist-version-semver,
                    "apps": array {
                        for $app in $compatible-apps
                        let $pkg := $app?newest
                        return
                            map:merge((
                                map {
                                    "name": $pkg/name/string(),
                                    "abbrev": $pkg/abbrev[not(@type)]/string(),
                                    "title": $pkg/title/string(),
                                    "version": $pkg/version/string(),
                                    "description": $pkg/description/string(),
                                    "path": $pkg/@path/string(),
                                    "size": xs:integer($pkg/@size),
                                    "sha256": $pkg/@sha256/string()
                                },
                                if ($pkg/author) then map { "authors": array { $pkg/author/string() } } else (),
                                if ($pkg/license) then map { "license": $pkg/license/string() } else (),
                                if ($pkg/website[. ne ""]) then map { "website": $pkg/website/string() } else (),
                                if (exists($app?older)) then
                                    map {
                                        "older": array {
                                            for $old in $app?older
                                            return map {
                                                "version": $old/version/string(),
                                                "path": $old/@path/string(),
                                                "size": xs:integer($old/@size)
                                            }
                                        }
                                    }
                                else ()
                            ))
                    }
                },
                map { "method": "json" }
            )
        ) else (
            element apps {
                attribute version { $exist-version-semver },
                for $app in $compatible-apps
                let $newest-package := $app?newest
                let $older-packages := $app?older
                return
                    element app {
                        $newest-package/@*,
                        $newest-package/*,
                        if (exists($older-packages)) then
                            element older {
                                for $package in $older-packages
                                return
                                    element version {
                                        $package/@*,
                                        $package/requires
                                    }
                            }
                        else
                            ()
                    }
            }
        )
    )
