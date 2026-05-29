xquery version "3.1";

(:~
 : Allows download of packages
 :
 : Responds to requests like:
 : - /exist/apps/public-repo/public/eXide-1.0.0.xar
 : - /exist/apps/public-repo/public/eXide-1.0.0.xar.zip
 :
 : Uses response:stream-binary#3 for compatibility with both eXist 6.x and 7.x.
 : See https://github.com/eXist-db/public-repo/issues/104
 :)

import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm";
import module namespace log="http://exist-db.org/xquery/app/log" at "log.xqm";

declare namespace compression="http://exist-db.org/xquery/compression";
declare namespace request="http://exist-db.org/xquery/request";
declare namespace response="http://exist-db.org/xquery/response";
declare namespace util="http://exist-db.org/xquery/util";


let $filename := request:get-parameter("filename", ())
let $wants-zip as xs:boolean := ends-with($filename, ".zip")
let $xar-filename :=
    if ($wants-zip) then (
        (: strip .zip from resource name :)
        replace($filename, ".zip$", "")
    ) else (
        $filename
    )
let $path := $config:packages-col || "/" || $xar-filename
let $package := doc($config:raw-packages-doc)//package[@path eq $filename]
return
    if (util:binary-doc-available($path) and exists($package)) then (
        log:get-package-event($package),
        let $xar := util:binary-doc($path)
        return (
            if ($wants-zip) then (
                let $entry := <entry type="binary" method="store" name="/{$xar-filename}">{$xar}</entry>
                let $zip := compression:zip($entry, false())
                return
                    response:stream-binary($zip, "application/zip", $filename)
            ) else (
                response:stream-binary($xar, "application/zip", $xar-filename)
            )
        )
    ) else (
        log:package-not-found-event("Get Package by name """ || $xar-filename || """"),
        response:set-status-code(404),
        response:set-header("Content-Type", "application/xml"),
        <error>
            <status>404</status>
            <message>Package file "{$xar-filename}" not found.</message>
        </error>
    )
