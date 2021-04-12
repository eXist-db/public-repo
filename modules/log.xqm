xquery version "3.1";

(:~
 : Module handling writing to the structured application event log
 :
 : If $config:logs-col is /db/apps/public-repo-data/logs
 : all events for the 1st of January 2020 are listed in 
 : /db/apps/public-repo-data/logs/2020/01/public-repo-log-2020-01-01.xml.
 :
 : It contains something like:
    <public-repo-log>
        <event>
            <dateTime>2020-01-01T16:12:10.063+01:00</dateTime>
            <type>put-package</type>
            <package-name>http://exist-db.org/apps/public-repo</package-name>
            <package-version>2.0.0</package-version>
        </event>
        <event>
            <dateTime>2020-01-01T17:29:00.063+01:00</dateTime>
            <type>get-package</type>
            <package-name>http://exist-db.org/apps/public-repo</package-name>
            <package-version>2.0.0</package-version>
        </event>
        ...
    </public-repo-log>
 :)
module namespace log="http://exist-db.org/xquery/app/log";

import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm";
import module namespace scanrepo="http://exist-db.org/xquery/admin/scanrepo" at "scan.xqm";

(:~
 : Append entries to the structured application event log
 :  
 : @param $event the event to be appended
 : @returns nothing
 :)
declare function log:event($event as element(event)) as empty-sequence() {
    let $today := current-date()
    let $log-collection-name := log:collection($today)
    let $log-collection := $config:logs-col || "/" || $log-collection-name
    let $log-document-name := log:document-name($today)
    let $log-document := $log-collection || "/" || $log-document-name
    let $store-log :=
        if (doc-available($log-document)) then 
            update insert $event into doc($log-document)/public-repo-log
        else 
            ( 
                if (xmldb:collection-available($log-collection)) then
                    ()
                else
                    log:mkcol($config:logs-col, $log-collection-name),
                scanrepo:store($log-collection, $log-document-name, element public-repo-log { $event })
            )
    return
        ()
};

declare %private function log:collection($date as xs:date) {
    format-date($date, "[Y]/[M01]")
};

declare %private function log:document-name($date as xs:date) {
    "public-repo-log-" || format-date($date, "[Y]-[M01]-[D01]") || ".xml"
};

(:~
 : Recursively create a collection hierarchy
 :)
declare %private function log:mkcol($collection as xs:string, $path as xs:string) {
    log:mkcol-recursive($collection, tokenize($path, "/"))
};

declare 
    %private
function log:mkcol-recursive($collection as xs:string, $components as xs:string*) {
    if (exists($components)) then
        let $newColl := concat($collection, "/", $components[1])
        return (
            xmldb:create-collection($collection, $components[1]) ! 
                (
                    sm:chgrp(xs:anyURI(.), config:repo-permissions()?mode),
                    .
                ),
            log:mkcol-recursive($newColl, subsequence($components, 2))
        )
    else
        ()
};
