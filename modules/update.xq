xquery version "3.1";

(:~
 : Rebuild metadata for all packages 
 :)

import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm";
import module namespace scanrepo="http://exist-db.org/xquery/admin/scanrepo" at "scan.xqm";

declare namespace sm="http://exist-db.org/xquery/securitymanager";

let $permissions := config:repo-descriptor()/repo:permissions
let $repo-user := $permissions/@user
let $repo-group := $permissions/@group
return
    if (sm:id()/sm:id/sm:real/sm:groups/sm:group = $repo-group) then
        (
            scanrepo:rebuild-raw-packages(), 
            scanrepo:rebuild-package-groups()
        )
    else
        system:as-user(
            $repo-user, 
            $repo-group, 
            (
                scanrepo:rebuild-raw-packages(), 
                scanrepo:rebuild-package-groups()
            )
        )
