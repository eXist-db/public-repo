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
let $semVer := request:get-parameter("semver", ())
let $minVersion := request:get-parameter("semver-min", ())
let $maxVersion := request:get-parameter("semver-max", ())
let $version := request:get-parameter("version", ())
let $zip := request:get-parameter("zip", ())
let $info := request:get-parameter("info", ())
let $procVersion := request:get-parameter("processor", $config:default-exist-version)
let $app-root-absolute-url := request:get-parameter("app-root-absolute-url", ())

let $package-group :=
    if ($name) then
        doc($config:package-groups-doc)//package-group[name eq $name]
    else
        doc($config:package-groups-doc)//package-group[abbrev eq $abbrev]

let $compatible-package := versions:find-compatible-packages($package-group//package, $procVersion, $version, $semVer, $minVersion, $maxVersion)

return
    if ($compatible-package) then
        (: TODO shouldn't we get $abs-public from $config? - joewiz :)
        let $abs-public := $app-root-absolute-url || "/public/"
        let $xar-filename := $compatible-package/@path
        return
            if ($info) then
                element found {
                    $compatible-package/@sha256, 
                    $compatible-package/version ! attribute version {.},
                    $compatible-package/@path
                }
            else if ($zip) then
                response:redirect-to(xs:anyURI($abs-public || $xar-filename || ".zip"))
            else
                response:redirect-to(xs:anyURI($abs-public || $xar-filename))
    else (
        response:set-status-code(404),
        <p>Package file not found!</p>
    )
