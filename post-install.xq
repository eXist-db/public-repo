xquery version "3.1";

(:~
 : This post-install script sets permissions on the package data collection hierarchy.
 : When pre-install creates the public-repo-data collection, its permissions are admin/dba.
 : This ensures the collections are owned by the default user and group for the app.
 : The script also builds the package metadata if it doesn't already exist.
 :)

import module namespace config="http://exist-db.org/xquery/apps/config" at "modules/config.xqm";
import module namespace dbu="http://exist-db.org/xquery/utility/db" at "modules/db-utility.xqm";
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

declare variable $settings :=
    <settings>
        <featured/>
    </settings>
;

declare variable $permissions := config:repo-permissions();

(: Create the data collection hierarchy and set the package permissions :)

for-each((
$config:app-data-col,
$config:packages-col,
$config:icons-col,
$config:metadata-col,
$config:logs-col
), dbu:ensure-collection(?)),

(: create empty settings if needed :)
if (doc-available($config:app-data-col || '/' || $config:settings-doc-name)) then () else (
    xmldb:store($config:app-data-col, $config:settings-doc-name, $settings)
),

(: Create log indexes :)

"/db/system/config" || $config:logs-col
=> dbu:ensure-collection(map {"owner": "SYSTEM", "group": "dba", "mode": "rwxr-xr-x"})
=> xmldb:store("collection.xconf", $logs-xconf)
=> dbu:set-permissions(map {"owner": "SYSTEM", "group": "dba", "mode": "rw-r--r--"})
,
xmldb:reindex($config:logs-col),

(: Build package metadata if missing :)

if (doc-available($config:raw-packages-doc) and doc-available($config:package-groups-doc)) then
    ()
else
    scanrepo:rebuild-all-package-metadata() ! sm:chown(xs:anyURI(.), config:repo-permissions()?owner),

(: Ensure get-package.xq is run as "repo:repo", so that logs will always be writable :)
sm:chmod(xs:anyURI($target || "/modules/get-package.xq"), "rwsr-sr-x")
