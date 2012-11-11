xquery version "3.0";

import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm";

let $name := request:get-parameter("abbrev", ())
return
    if ($name) then
        let $app := collection($config:app-root || "/public")//app[abbrev = $name]
        return
            if ($app) then
                let $xar := util:binary-doc($config:app-root || "/public/" || $app/@path)
                let $entry :=
                    <entry type="binary" method="store" name="/{$app/@path}" strip-prefix="false">{$xar}</entry>
                let $zip := compression:zip($entry, false())
                return
                    response:stream-binary($zip, "application/zip", "pkg.zip")
            else (
                response:set-status-code(404),
                <p>Package file {$app/@path/string()} not found!</p>
            )
    else (
        response:set-status-code(404),
        <p>Package with URI {$name} not found!</p>
    )