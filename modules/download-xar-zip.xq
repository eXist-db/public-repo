xquery version "3.1";

import module namespace compression="http://exist-db.org/xquery/compression";
import module namespace response="http://exist-db.org/xquery/response";
import module namespace util="http://exist-db.org/xquery/util";

import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm";

let $pkg-file-name := fn:replace(request:get-url(), ".*/(.*)\.zip", "$1")
let $xar := util:binary-doc($config:app-root || "/public/" || $pkg-file-name)
return
    let $entry :=
        <entry type="binary" method="store" name="/{$pkg-file-name}" strip-prefix="false">{$xar}</entry>
    let $zip := compression:zip($entry, false())
    return
        response:stream-binary($zip, "application/zip")
