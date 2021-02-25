xquery version "3.1";

(:~
 : This pre-install script creates the data collection hierarchy which the app
 : uses to store packages and package assets. The names of these collections are
 : defined in the modules/config.xqm module. Since the pre-install script
 : runs before the package has been stored in the database, we read these values
 : from the location on disk where the unpacked .xar resides.
 :)

declare namespace xmldb="http://exist-db.org/xquery/xmldb";

(: The following external variables are set by the repo:deploy function :)

(: File path pointing to the exist installation directory :)
declare variable $home external;
(: Path to the directory containing the unpacked .xar package :)
declare variable $dir external;
(: The target collection into which the app is deployed :)
declare variable $target external;

(: Helper function to recursively create a collection hierarchy :)
declare function local:mkcol-recursive($collection as xs:string, $components as xs:string*) {
    if (exists($components)) then
        let $newColl := concat($collection, "/", $components[1])
        return (
            xmldb:create-collection($collection, $components[1]),
            local:mkcol-recursive($newColl, subsequence($components, 2))
        )
    else
        ()
};

(: Create a collection hierarchy :)
declare function local:mkcol($collection as xs:string, $path as xs:string) {
    local:mkcol-recursive($collection, tokenize($path, "/"))
};

(: Configuration file for the logs collection :)
declare variable $logs-xconf := 
    <collection xmlns="http://exist-db.org/collection-config/1.0" xmlns:xs="http://www.w3.org/2001/XMLSchema">
        <index>
            <range>
                <create qname="type" type="xs:string"/>
            </range>
        </index>
    </collection>;

(: Read the collection names from modules/config.xqm :)

let $config-module-ns := "http://exist-db.org/xquery/apps/config"
let $config-module-variables := 
    fn:load-xquery-module(
        $config-module-ns,
        map { "location-hints": $dir || "/modules/config.xqm" }
    )?variables 
    => map:for-each(function($name, $value) { map:entry(fn:local-name-from-QName($name), $value) })
let $app-data-parent-col := $config-module-variables?app-data-parent-col
let $app-data-col-name := $config-module-variables?app-data-col-name
let $app-data-col := $config-module-variables?app-data-col
let $icons-col-name := $config-module-variables?icons-col-name
let $metadata-col-name := $config-module-variables?metadata-col-name
let $packages-col-name := $config-module-variables?packages-col-name
let $logs-col-name := $config-module-variables?logs-col-name
let $logs-col := $config-module-variables?logs-col
return
    (
        (: Create the data collection hierarchy :)
        
        xmldb:create-collection($app-data-parent-col, $app-data-col-name),
        for $col-name in ($icons-col-name, $metadata-col-name, $packages-col-name, $logs-col-name)
        return
            xmldb:create-collection($app-data-col, $col-name),

        (: Create log indexes :)
        (: Store the collection configuration :)
        local:mkcol("/db/system/config", $config-module-variables?logs-col),
        xmldb:store("/db/system/config" || $config-module-variables?logs-col, "collection.xconf", $logs-xconf),
        xmldb:reindex($config-module-variables?logs-col)
    )