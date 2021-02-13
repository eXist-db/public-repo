xquery version "3.1";

(: rebuild metadata for all packages :)

import module namespace scanrepo="http://exist-db.org/xquery/admin/scanrepo" at "scan.xql";

declare namespace sm="http://exist-db.org/xquery/securitymanager";

if (sm:id()/sm:id/sm:real/sm:groups/sm:group = "repo") then
    (
        scanrepo:rebuild-package-meta(), 
        scanrepo:scan()
    )
else
    system:as-user(
        "repo", 
        "repo", 
        (
            scanrepo:rebuild-package-meta(), 
            scanrepo:scan()
        )
    )