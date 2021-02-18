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

declare namespace repo="http://exist-db.org/xquery/repo";

(: Until https://github.com/eXist-db/exist/issues/3734 is fixed, we hard code the default user and group :)

declare variable $local:owner-user := 
    (: config:repo-descriptor()/repo:permissions/@user :)
    "repo";
declare variable $local:owner-group := 
    (: config:repo-descriptor()/repo:permissions/@group :)
    "repo";

(:~
 : Set user and group to be owner by values in repo.xml
 :)
declare function local:chgrp-repo($resource as xs:string) {
    if (sm:get-permissions(xs:anyURI($resource))/sm:permission/@group = $local:owner-group) then
        ()
    else
        (
            sm:chown($resource, $local:owner-user),
            sm:chgrp($resource, $local:owner-group)
        )
};

(: Set user and group ownership on the package data collection hierarchy :)

for $col in ($config:app-data-col, xmldb:get-child-collections($config:app-data-col) ! ($config:app-data-col || "/" || .))
return
    local:chgrp-repo($col),

(: Build package metadata if missing :)

if (doc-available($config:raw-packages-doc) and doc-available($config:package-groups-doc)) then
    ()
else
    system:as-user(
        $local:owner-user, 
        $local:owner-group, 
        (
            scanrepo:rebuild-raw-packages(), 
            scanrepo:rebuild-package-groups()
        )
    )
