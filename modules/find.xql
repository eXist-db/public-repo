xquery version "3.1";

import module namespace request="http://exist-db.org/xquery/request";
import module namespace response="http://exist-db.org/xquery/response";

import module namespace app="http://exist-db.org/xquery/app" at "app.xql";
import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm";

let $abbrev := request:get-parameter("abbrev", ())
let $name := request:get-parameter("name", ())
let $semVer := request:get-parameter("semver", ())
let $minVersion := request:get-parameter("semver-min", ())
let $maxVersion := request:get-parameter("semver-max", ())
let $version := request:get-parameter("version", ())
let $zip := request:get-parameter("zip", ())
let $info := request:get-parameter("info", ())
let $procVersion := request:get-parameter("processor", "2.2.0")
let $app-root-absolute-url := request:get-parameter("app-root-absolute-url", ())
let $app :=
    if ($name) then
        doc($config:apps-meta)//app[name eq $name]
    else
        doc($config:apps-meta)//app[abbrev eq $abbrev]
let $app-versions := ($app, $app/other/version)
let $compatible-xar := app:find-version($app-versions, $procVersion, $version, $semVer, $minVersion, $maxVersion)
return
    if ($compatible-xar) then
        let $abs-public := $app-root-absolute-url || "/public/"
        return
            if ($info) then
                let $app := doc($config:apps-meta)//(app|version)[@path eq $compatible-xar]
                return
                    <found>{$app/@sha256,($app/version,$app/@version)[1] ! attribute version {.},$compatible-xar}</found>
            else if ($zip) then
                response:redirect-to(xs:anyURI($abs-public || $compatible-xar || ".zip"))
            else
                response:redirect-to(xs:anyURI($abs-public || $compatible-xar))
    else (
        response:set-status-code(404),
        <p>Package file {$compatible-xar} not found!</p>
    )
