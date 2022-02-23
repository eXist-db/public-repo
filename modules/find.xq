xquery version "3.1";

(:~
 : Respond to eXist build requests for packages using various identifier and version number criteria
 :
 : The info parameter can be used for troubleshooting
 :)

import module namespace app="http://exist-db.org/xquery/app" at "app.xqm";
import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm";
import module namespace versions="http://exist-db.org/apps/public-repo/versions" at "versions.xqm";

declare namespace request="http://exist-db.org/xquery/request";
declare namespace response="http://exist-db.org/xquery/response";

let $abbrev := request:get-parameter("abbrev", ())
let $name := request:get-parameter("name", ())
let $exist-version-semver := request:get-parameter("processor", $config:default-exist-version)
let $version := request:get-parameter("version", ())
let $semver := request:get-parameter("semver", ())
let $semver-min := request:get-parameter("semver-min", ())
let $semver-max := request:get-parameter("semver-max", ())
let $zip := request:get-parameter("zip", ())
let $info := request:get-parameter("info", ())
let $app-root-absolute-url := request:get-parameter("app-root-absolute-url", ())

let $package-group :=
    if ($name) then
        doc($config:package-groups-doc)//package-group[name eq $name]
    else
        doc($config:package-groups-doc)//package-group[abbrev eq $abbrev]

let $newest-compatible-package := versions:find-newest-compatible-package($package-group//package, $exist-version-semver, $version, $semver, $semver-min, $semver-max)

return
    if ($newest-compatible-package) then
        (: TODO shouldn't we get $abs-public from $config? - joewiz :)
        let $abs-public := $app-root-absolute-url || "/public/"
        let $xar-filename := $newest-compatible-package/@path
        return
            if ($info) then
                element found {
                    $newest-compatible-package/@sha256, 
                    $newest-compatible-package/version ! attribute version {.},
                    $newest-compatible-package/@path
                }
            else if ($zip) then
                app:redirect-to($abs-public || $xar-filename || ".zip")
            else
                app:redirect-to($abs-public || $xar-filename)
    else 
        (
            response:set-status-code(404),
            <p>Package file not found!</p>
        )
