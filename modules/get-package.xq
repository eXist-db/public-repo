xquery version "3.1";

(:~
 : Allows download of packages
 :
 : Responds to requests like:
 : - /exist/apps/public-repo/public/eXide-1.0.0.xar
 : - /exist/apps/public-repo/public/eXide-1.0.0.xar.zip
 :)

import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm";
import module namespace log="http://exist-db.org/xquery/app/log" at "log.xqm";

declare namespace compression="http://exist-db.org/xquery/compression";
declare namespace request="http://exist-db.org/xquery/request";
declare namespace response="http://exist-db.org/xquery/response";
declare namespace util="http://exist-db.org/xquery/util";

declare function local:log-get-package-event($filename as xs:string) as empty-sequence() {
    let $package := doc($config:raw-packages-doc)//package[@path eq $filename]
    let $event :=
        element event {
            element dateTime { current-dateTime() },
            element type { "get-package" },
            element package-name { $package/name/string() },
            element package-version { $package/version/string() }
        }
    return
        log:event($event)
};

declare function local:log-package-not-found-event($filename as xs:string) as empty-sequence() {
    log:event(
        element event {
            element dateTime { current-dateTime() },
            element type { "not-found" },
            element file-name { $filename }
        }
    )
};


let $filename := request:get-parameter("filename", ())
let $wants-zip as xs:boolean := ends-with($filename, ".zip")
let $xar-filename :=
    (: strip .zip from resource name :)
    if ($wants-zip) then
        replace($filename, ".zip$", "")
    else
        $filename
let $path := $config:packages-col || "/" || $xar-filename
return
    if (util:binary-doc-available($path)) then
        let $xar := util:binary-doc($config:packages-col || "/" || $xar-filename)
        let $log := local:log-get-package-event($xar-filename)
        return
            if ($wants-zip) then
                let $entry := <entry type="binary" method="store" name="/{$xar-filename}" strip-prefix="false">{$xar}</entry>
                let $zip := compression:zip($entry, false())
                return
                    response:stream-binary($zip, "application/zip")
            else
                response:stream-binary($xar, "application/zip")
    else
        (
            response:set-status-code(404),
            <p>Package file not found!</p>
        )
