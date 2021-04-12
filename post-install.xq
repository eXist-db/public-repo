xquery version "3.1";

(:~
 : This post-install script sets permissions on the package data collection hierarchy.
 : When pre-install creates the public-repo-data collection, its permissions are admin/dba. 
 : This ensures the collections are owned by the default user and group for the app.
 : The script also builds the package metadata if it doesn't already exist.
 :)
 
import module namespace config="http://exist-db.org/xquery/apps/config" at "modules/config.xqm";
import module namespace scanrepo="http://exist-db.org/xquery/admin/scanrepo" at "modules/scan.xqm";

declare namespace sm="http://exist-db.org/xquery/securitymanager";
declare namespace system="http://exist-db.org/xquery/system";
declare namespace xmldb="http://exist-db.org/xquery/xmldb";

(: The following external variables are set by the repo:deploy function :)

(: file path pointing to the exist installation directory :)
declare variable $home external;
(: path to the directory containing the unpacked .xar package :)
declare variable $dir external;
(: the target collection into which the app is deployed :)
declare variable $target external;

(: Configuration file for the logs collection :)
declare variable $logs-xconf := 
    <collection xmlns="http://exist-db.org/collection-config/1.0" xmlns:xs="http://www.w3.org/2001/XMLSchema">
        <index>
            <range>
                <create qname="type" type="xs:string"/>
            </range>
        </index>
    </collection>;

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

(:~
 : Set user and group to be owner by values in repo.xml
 :)
declare function local:set-data-collection-permissions($resource as xs:string) {
    if (sm:get-permissions(xs:anyURI($resource))/sm:permission/@group = config:repo-permissions()?group) then
        ()
    else
        (
            sm:chown($resource, config:repo-permissions()?user),
            sm:chgrp($resource, config:repo-permissions()?group),
            sm:chmod(xs:anyURI($resource), config:repo-permissions()?mode)
        )
};

(: Create the data collection hierarchy :)

xmldb:create-collection($config:app-data-parent-col, $config:app-data-col-name),
for $col-name in ($config:icons-col-name, $config:metadata-col-name, $config:packages-col-name, $config:logs-col-name)
return
    xmldb:create-collection($config:app-data-col, $col-name),

(: Create log indexes :)

local:mkcol("/db/system/config", $config:logs-col),
xmldb:store("/db/system/config" || $config:logs-col, "collection.xconf", $logs-xconf),
xmldb:reindex($config:logs-col),

(: Set user and group ownership on the package data collection hierarchy :)

for $col in ($config:app-data-col, xmldb:get-child-collections($config:app-data-col) ! ($config:app-data-col || "/" || .))
return
    local:set-data-collection-permissions($col),

(: Build package metadata if missing :)

if (doc-available($config:raw-packages-doc) and doc-available($config:package-groups-doc)) then
    ()
else
    scanrepo:rebuild-all-package-metadata(),
    
(: Ensure get-package.xq is run as "repo" group, so that it can write to logs :)

sm:chmod(xs:anyURI($target || "/modules/get-package.xq"), "g+s")
