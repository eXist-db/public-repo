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
import module namespace dbu="http://exist-db.org/xquery/utility/db" at "db-utility.xqm";

declare variable $log:base-collection := $config:logs-col;
declare variable $log:file-permission := map:merge((
    $dbu:default-permissions,
    map { "mode": "rw-rw-r--" }
));

(:~
 : Append entries to the structured application event log
 :  
 : @param $event the event to be appended
 : @returns nothing
 :)
declare function log:event($event as element(event)) as empty-sequence() {
    let $today := current-date()
    let $log-collection := log:collection($today)
    let $log-document-name := log:document-name($today)
    
    return
        if (doc-available($log-collection || "/" || $log-document-name))
        then log:append-log($log-collection, $log-document-name, $event)
        else log:create-log($log-collection, $log-document-name, $event)
};

declare %private
function log:append-log ($log-collection as xs:string, $log-document-name as xs:string, $event as element(event)) as empty-sequence() {
    let $node := doc($log-collection || "/" || $log-document-name)/public-repo-log
    let $update := update insert $event into $node
    return ()
};

declare %private
function log:create-log ($log-collection as xs:string, $log-document-name as xs:string, $event as element(event)) as empty-sequence() {
    dbu:ensure-collection($log-collection)
    => xmldb:store($log-document-name, element public-repo-log { $event })
    => dbu:set-permissions($log:file-permission)
    => log:return-empty()
};

declare %private
function log:return-empty ($item as item()*) as empty-sequence() {}; 

declare %private function log:collection($date as xs:date) as xs:string {
    $log:base-collection || "/" || format-date($date, "[Y]/[M01]")
};

declare %private function log:document-name($date as xs:date) as xs:string {
    "public-repo-log-" || format-date($date, "[Y]-[M01]-[D01]") || ".xml"
};
