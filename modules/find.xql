xquery version "3.0";

import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm";
import module namespace scanrepo="http://exist-db.org/xquery/admin/scanrepo" at "scan.xql";

declare function local:find-version($apps as element()*, $procVersion as xs:string, $version as xs:string?, $semVer as xs:string?, $min as xs:string?, $max as xs:string?) {
    if (empty($apps)) then
        ()
    else
        if ($semVer) then
            scanrepo:find-version($apps, $semVer, $semVer)/@path
        else if ($version) then
            $apps[version = $version]/@path | $apps[@version = $version]/@path
        else if ($min or $max) then
            scanrepo:find-version($apps, $min, $max)/@path
        else
            scanrepo:find-newest($apps, (), $procVersion)/@path
};

let $abbrev := request:get-parameter("abbrev", ())
let $name := request:get-parameter("name", ())
let $semVer := request:get-parameter("semver", ())
let $minVersion := request:get-parameter("semver-min", ())
let $maxVersion := request:get-parameter("semver-max", ())
let $version := request:get-parameter("version", ())
let $zip := request:get-parameter("zip", ())
let $procVersion := request:get-parameter("processor", "2.2.0")
let $app :=
    if ($name) then
        collection($config:app-root || "/public")//app[name = $name]
    else
        collection($config:app-root || "/public")//app[abbrev = $abbrev]
let $path := local:find-version($app | $app/other/version, $procVersion, $version, $semVer, $minVersion, $maxVersion)
return
    if ($path) then
        let $xar := util:binary-doc($config:app-root || "/public/" || $path)
        return
            if ($zip) then
                let $entry :=
                    <entry type="binary" method="store" name="/{$app/@path}" strip-prefix="false">{$xar}</entry>
                let $zip := compression:zip($entry, false())
                return
                    response:stream-binary($zip, "application/zip", "pkg.zip")
            else
                response:stream-binary($xar, "application/zip", $path)
    else (
        response:set-status-code(404),
        <p>Package file {$path} not found!</p>
    )