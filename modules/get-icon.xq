xquery version "3.1";

(:~
 : Allows download of icons
 :
 : Responds to requests like:
 : - /exist/apps/public-repo/public/eXide-1.0.0.png
 : - /exist/apps/public-repo/public/eXide-1.0.0.svg
 :)

import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm";

declare namespace request="http://exist-db.org/xquery/request";
declare namespace response="http://exist-db.org/xquery/response";
declare namespace util="http://exist-db.org/xquery/util";

let $filename := request:get-parameter("filename", ())
let $path := xs:anyURI($config:icons-col || "/" || $filename)
return
    (: svg :)
    if (doc-available($path)) then
        response:stream(doc($path), "media-type=" || xmldb:get-mime-type($path))
    (: png :)
    else if (util:binary-doc-available($path)) then
        response:stream-binary(util:binary-doc($path), xmldb:get-mime-type($path))
    else
        (
            response:set-status-code(404),
            <p>Icon file not found!</p>
        )
