xquery version "3.0";

import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm";

let $abbrev := request:get-parameter("abbrev", ())
let $name := request:get-parameter("name", ())
let $version := request:get-parameter("version", ())
let $zip := request:get-parameter("zip", ())
let $app :=
    if ($name) then
        collection($config:app-root || "/public")//app[name = $name]
    else
        collection($config:app-root || "/public")//app[abbrev = $abbrev]
let $path :=
    if ($version) then
        $app[version = $version]/@path | $app/other/version[@version = $version]/@path
    else
        $app/@path
return
    if ($app) then
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