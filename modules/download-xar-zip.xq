xquery version "3.1";

(:~
 : Allows download of packages via zip extension
 :
 : Responds to requests like /exist/apps/public-repo/public/eXide-1.0.0.xar.zip
 :)

import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm";

declare namespace compression="http://exist-db.org/xquery/compression";
declare namespace request="http://exist-db.org/xquery/request";
declare namespace response="http://exist-db.org/xquery/response";
declare namespace util="http://exist-db.org/xquery/util";

(: strip .zip from resource name :)
let $xar-filename := fn:replace(request:get-url(), ".*/(.*)\.zip", "$1")
let $xar := util:binary-doc($config:packages-col || "/" || $xar-filename)
return
    response:stream-binary($xar, "application/zip")
