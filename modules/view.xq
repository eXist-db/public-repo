xquery version "3.1";

import module namespace app="http://exist-db.org/xquery/app" at "app.xqm";
import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm";

import module namespace site="http://exist-db.org/apps/site-utils";
import module namespace templates="http://exist-db.org/xquery/html-templating";

declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

declare option output:method "html";
declare option output:html-version "5";
declare option output:media-type "text/html";

declare option exist:timeout "300000";

let $config := map {
    $templates:CONFIG_APP_ROOT : $config:app-root
}
let $lookup := function($functionName as xs:string, $arity as xs:int) {
    try {
        function-lookup(xs:QName($functionName), $arity)
    } catch * {
        ()
    }
}
let $content := request:get-data()
return
    templates:apply($content, $lookup, (), $config)
