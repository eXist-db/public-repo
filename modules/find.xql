xquery version "3.0";

import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm";

let $abbrev := request:get-parameter("abbrev", ())
let $name := request:get-parameter("name", ())
let $zip := request:get-parameter("zip", ())
let $app :=
    if ($name) then
        collection($config:app-root || "/public")//app[name = $name]
    else
        collection($config:app-root || "/public")//app[abbrev = $abbrev]
return
    if ($app) then
        let $xar := util:binary-doc($config:app-root || "/public/" || $app/@path)
        return
            if ($zip) then
                let $entry :=
                    <entry type="binary" method="store" name="/{$app/@path}" strip-prefix="false">{$xar}</entry>
                let $zip := compression:zip($entry, false())
                return
                    response:stream-binary($zip, "application/zip", "pkg.zip")
            else
                response:stream-binary($xar, "application/zip", $app/@path)
    else (
        response:set-status-code(404),
        <p>Package file {$app/@path/string()} not found!</p>
    )