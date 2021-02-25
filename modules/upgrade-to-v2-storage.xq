xquery version "3.1";

(:~
 : A script for upgrading public-repo's storage format to v2.
 : 
 : This script is only needed if you are preparing to upgrade from public-repo v0-1 to public-repo v2+.
 :)

import module namespace semver = "http://exist-db.org/xquery/semver";

declare namespace pkg="http://expath.org/ns/pkg";
declare namespace repo="http://exist-db.org/xquery/repo";
declare namespace sm="http://exist-db.org/xquery/securitymanager";
declare namespace xmldb="http://exist-db.org/xquery/xmldb";

declare function local:chgrp-repo($path) {
    if (sm:get-permissions($path)/*/@group = "repo") then
        ()
    else
        (
            sm:chown($path, "repo"),
            sm:chgrp($path, "repo")
        )
};

declare function local:upgrade-to-public-repo-2-storage() as element()+ {
    (: create new collections :)
    element collections {
        (
        xmldb:create-collection("/db/apps", "public-repo-data"),
        for $subcollection in ("icons", "metadata", "packages")
        return
            xmldb:create-collection("/db/apps/public-repo-data", $subcollection)
        ) ! 
        (
            local:chgrp-repo(.),
            element collection { . }
        )
    },
    
    (: move xars and icons to new collections :)
    if (xmldb:collection-available("/db/apps/public-repo/public")) then
        (
            element packages {
                for $package in xmldb:get-child-resources("/db/apps/public-repo/public")[ends-with(., ".xar")]
                return
                    xmldb:copy-resource("/db/apps/public-repo/public", $package, "/db/apps/public-repo-data/packages", $package, true()) !
                    (
                        local:chgrp-repo(.),
                        element package { . } 
                    )
            },
            element icons {
                for $icon in xmldb:get-child-resources("/db/apps/public-repo/public")[not(matches(., "\.(xar|xml)$"))]
                return
                    xmldb:copy-resource("/db/apps/public-repo/public", $icon, "/db/apps/public-repo-data/icons", $icon, true())
                    ! 
                    (
                        local:chgrp-repo(.),
                        element icon { . }
                    )
            }
        )
    else
        ()
};

if (repo:list() = "http://exist-db.org/apps/public-repo") then
    if (semver:lt(doc("/db/apps/public-repo/expath-pkg.xml")/pkg:package/@version, "2.0.0")) then
        element status {
            element description { "Upgrade of public-repo storage to v2 format is complete. Please install latest public-repo v2+." },
            local:upgrade-to-public-repo-2-storage()
        }
    else
        element status { 
            element description { "No action taken. A version of public-repo with the v2 format is already installed." }
        }
else
    element status { 
        element description { "No action taken. The public-repo app is not installed." }
    }
