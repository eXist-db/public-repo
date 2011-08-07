xquery version "1.0";

import module namespace xdb="http://exist-db.org/xquery/xmldb";

(: The following external variables are set by the repo:deploy function :)

(: file path pointing to the exist installation directory :)
declare variable $home external;
(: path to the directory containing the unpacked .xar package :)
declare variable $dir external;
(: the target collection into which the app is deployed :)
declare variable $target external;

declare function local:mkcol-recursive($collection, $components) {
    if (exists($components)) then
        let $newColl := concat($collection, "/", $components[1])
        return (
            xdb:create-collection($collection, $components[1]),
            local:mkcol-recursive($newColl, subsequence($components, 2))
        )
    else
        ()
};

(: Helper function to recursively create a collection hierarchy. :)
declare function local:mkcol($collection, $path) {
    local:mkcol-recursive($collection, tokenize($path, "/"))
};

declare function local:get-repo-dir() {
    let $home := system:get-exist-home()
    let $pathSep := util:system-property("file.separator")
    return
        if (doc-available(concat("file:///", $home, "/webapp/repo/packages"))) then
            concat($home, "/webapp/repo/packages")
        else if(ends-with($home, "WEB-INF")) then
            concat(substring-before($home, "WEB-INF"), "/repo/packages")
        else
            concat($home, $pathSep, "/webapp/repo/packages")
};

(: store the collection configuration :)
local:mkcol($target, "public"),
xdb:store-files-from-pattern(concat($target, "/public"), local:get-repo-dir(), "*.xar")