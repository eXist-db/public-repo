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

(: file path pointing to the exist installation directory :)
declare variable $home external;
(: path to the directory containing the unpacked .xar package :)
declare variable $dir external;
(: the target collection into which the app is deployed :)
declare variable $target external;

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
return
    (
        (: Create the data collection hierarchy :)
        
        xmldb:create-collection($app-data-parent-col, $app-data-col-name),
        for $col-name in ($icons-col-name, $metadata-col-name, $packages-col-name)
        return
            xmldb:create-collection($app-data-col, $col-name)
    )