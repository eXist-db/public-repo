xquery version "3.1";

declare namespace xmldb="http://exist-db.org/xquery/xmldb";

(: The following external variables are set by the repo:deploy function :)

(: file path pointing to the exist installation directory :)
declare variable $home external;
(: path to the directory containing the unpacked .xar package :)
declare variable $dir external;
(: the target collection into which the app is deployed :)
declare variable $target external;

(: create public-repo-data and subcollections :)
xmldb:create-collection("/db/apps", "public-repo-data"),
for $col in ("icons", "metadata", "packages")
return
    xmldb:create-collection("/db/apps/public-repo-data", $col)