xquery version "3.0";

import module namespace request="http://exist-db.org/xquery/request";
import module namespace response="http://exist-db.org/xquery/response";

import module namespace app="http://exist-db.org/xquery/app" at "app.xql";
import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm";
import module namespace scanrepo="http://exist-db.org/xquery/admin/scanrepo" at "scan.xql";

let $abbrev := request:get-parameter("abbrev", ())
let $name := request:get-parameter("name", ())
let $semVer := request:get-parameter("semver", ())
let $minVersion := request:get-parameter("semver-min", ())
let $maxVersion := request:get-parameter("semver-max", ())
let $version := request:get-parameter("version", ())
let $zip := request:get-parameter("zip", ())
let $info := request:get-parameter("info", ())
let $procVersion := request:get-parameter("processor", "2.2.0")
let $apps :=
    if ($name) then
        collection($config:app-root || "/public")//app[name = $name]
    else
        collection($config:app-root || "/public")//app[abbrev = $abbrev]
let $path := app:find-version($apps | $apps/other/version, $procVersion, $version, $semVer, $minVersion, $maxVersion)
return
    if ($path) then
        let $rel-public :=
            if(contains(request:get-url(), "/modules/")) then
                "../public/"
            else
                "public/"
        return
            if ($info) then
                <found>{$app}</found>
            else if ($zip) then
                response:redirect-to(xs:anyURI($rel-public || $path || ".zip"))
            else 
                response:redirect-to(xs:anyURI($rel-public || $path))
    else (
        response:set-status-code(404),
        <p>Package file {$path} not found!</p>
    )
