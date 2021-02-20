xquery version "3.1";

(:~
 : Allows download of packages
 :
 : Responds to requests like:
 : - /exist/apps/public-repo/public/eXide-1.0.0.xar
 : - /exist/apps/public-repo/public/eXide-1.0.0.xar.zip
 :)

import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm";

declare namespace request="http://exist-db.org/xquery/request";
declare namespace response="http://exist-db.org/xquery/response";
declare namespace util="http://exist-db.org/xquery/util";

let $filename := request:get-parameter("filename", ())
let $xar-filename :=
    (: strip .zip from resource name :)
    if (ends-with($filename, ".zip")) then
        replace($filename, ".zip$", "")
    else
        $filename
let $path := $config:packages-col || "/" || $xar-filename
return
    if (util:binary-doc-available($path)) then
        let $xar := util:binary-doc($config:packages-col || "/" || $xar-filename)
        return
            response:stream-binary($xar, "application/zip")
    else
        (
            response:set-status-code(404),
            <p>Package file not found!</p>
        )
