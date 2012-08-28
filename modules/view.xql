xquery version "3.0";

import module namespace templates="http://exist-db.org/xquery/templates" at "templates.xql";
import module namespace app="http://exist-db.org/xquery/app" at "app.xql";
    
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

declare option output:method "html5";
declare option output:media-type "text/html";

let $lookup := function($functionName as xs:string, $arity as xs:int) {
    try {
        function-lookup(xs:QName($functionName), $arity)
    } catch * {
        ()
    }
}
let $content := request:get-data()
return
    templates:apply($content, $lookup, ())