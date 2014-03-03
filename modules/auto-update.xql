xquery version "3.0";

module namespace trigger="http://exist-db.org/xquery/trigger";
import module namespace scanrepo="http://exist-db.org/xquery/admin/scanrepo" at "xmldb:exist:///db/apps/public-repo/modules/scan.xql";

declare function trigger:after-create-document($uri as xs:anyURI) {
    if (ends-with($uri, ".xar")) then scanrepo:scan() else ()
};

declare function trigger:after-update-document($uri as xs:anyURI) {
    if (ends-with($uri, ".xar")) then scanrepo:scan() else ()
};

declare function trigger:after-delete-document($uri as xs:anyURI) {
    if (ends-with($uri, ".xar")) then scanrepo:scan() else ()
};
