xquery version "3.1";


module namespace log="http://exist-db.org/xquery/app/log";


import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm";


declare function log:event($event as element(event)) as empty-sequence() {
    let $today := current-date()
    let $log-document := log:doc($today)

    let $update-log :=
        if (doc-available($log-document)) then 
            update insert $event into doc($log-document)/public-repo-log
        else ( 
            log:mkcol($config:logs-col, log:subcollection($today)),
            xmldb:store(log:collection($today), 
                log:document-name($today), 
                element public-repo-log { $event })
        )

    return
        ()
};

declare function log:doc($date as xs:date) {
    log:collection($date) || "/" || log:document-name($date)
};

declare function log:subcollection($date as xs:date) {
    format-date($date, "[Y]/[M01]")
};

declare function log:collection($date as xs:date) {
    $config:logs-col || "/" || 
    log:subcollection($date)
};

declare function log:document-name($date as xs:date) {
    ``[public-repo-log-`{format-date($date, "[Y]-[M01]-[D01]")}`.xml]``
};

(:~
 : Utility function
 :)
declare 
    %private
function log:mkcol-recursive($collection as xs:string, $components as xs:string*) {
    if (exists($components)) then
        let $newColl := concat($collection, "/", $components[1])
        return (
            xmldb:create-collection($collection, $components[1]),
            log:mkcol-recursive($newColl, subsequence($components, 2))
        )
    else
        ()
};

(:~
 : Recursively create a collection hierarchy
 :)
declare function log:mkcol($collection as xs:string, $path as xs:string) {
    log:mkcol-recursive($collection, tokenize($path, "/"))
};
