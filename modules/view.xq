xquery version "3.1";


import module namespace templates="http://exist-db.org/xquery/html-templating";
import module namespace lib="http://exist-db.org/xquery/html-templating/lib";

import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm";
import module namespace app="http://exist-db.org/xquery/app" at "app.xqm";


declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

declare option output:method "html";
declare option output:html-version "5.0";
declare option output:media-type "text/html";
declare option output:indent "no";

declare function local:lookup ($function-name as xs:string, $arity as xs:integer) as function(*)? {
    function-lookup(xs:QName($function-name), $arity)
};

declare variable $local:templating-configuration := map {
    $templates:CONFIG_APP_ROOT : $config:app-root,
    $templates:CONFIG_USE_CLASS_SYNTAX : false(),
    $templates:CONFIG_FILTER_ATTRIBUTES : true(),
    $templates:CONFIG_STOP_ON_ERROR : true()
};

declare variable $local:initial-model := map {
    "show-top-nav-search": (
        request:get-parameter("top-nav-search", "no") = "yes"
    )
};


templates:apply(
    request:get-data(),
    local:lookup#2,
    $local:initial-model,
    $local:templating-configuration
)
