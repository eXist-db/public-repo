xquery version "3.1";

(:~
 : Rebuild metadata for all packages 
 :)

import module namespace scanrepo="http://exist-db.org/xquery/admin/scanrepo" at "scan.xqm";

scanrepo:rebuild-all-package-metadata()