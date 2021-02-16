xquery version "3.1";

import module namespace config="http://exist-db.org/xquery/apps/config" at "modules/config.xqm";
import module namespace scanrepo="http://exist-db.org/xquery/admin/scanrepo" at "modules/scan.xqm";

declare namespace sm="http://exist-db.org/xquery/securitymanager";
declare namespace system="http://exist-db.org/xquery/system";
declare namespace xmldb="http://exist-db.org/xquery/xmldb";

declare function local:chgrp-repo($resource) {
    if (sm:get-permissions($resource)/*/@group = "repo") then
        ()
    else
        (
            sm:chown($resource, "repo"),
            sm:chgrp($resource, "repo")
        )
};

(: set public-repo-data to "repo" group ownership if needed :)
for $col in ("/db/apps/public-repo-data", xmldb:get-child-collections("/db/apps/public-repo-data") ! ("/db/apps/public-repo-data/" || .))
return
    local:chgrp-repo($col),

(: build package metadata if missing :)
if (doc-available($config:packages-meta) and doc-available($config:apps-meta)) then
    ()
else
    system:as-user("repo", "repo", (scanrepo:rebuild-package-meta(), scanrepo:scan()))
