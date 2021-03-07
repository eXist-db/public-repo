xquery version "3.1";

(:~
 : Receives uploaded packages and immediately publishes them to the package repository
 :)

import module namespace app="http://exist-db.org/xquery/app" at "app.xqm";
import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm";
import module namespace log="http://exist-db.org/xquery/app/log" at "log.xqm";
import module namespace scanrepo="http://exist-db.org/xquery/admin/scanrepo" at "scan.xqm";

declare namespace request="http://exist-db.org/xquery/request";
declare namespace sm="http://exist-db.org/xquery/securitymanager";
declare namespace xmldb="http://exist-db.org/xquery/xmldb";

declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

declare option output:method "json";
declare option output:media-type "application/json";

declare function local:log-put-package-event($filename as xs:string) as empty-sequence() {
    let $package := doc($config:raw-packages-doc)//package[@path eq $filename]
    let $event := 
        element event {
            element dateTime { current-dateTime() },
            element type { "put-package" },
            element package-name { $package/name/string() },
            element package-version { $package/version/string() }
        }
    
    return
        log:event($event)
};

declare function local:upload-and-publish($xar-filename as xs:string, $xar-binary as xs:base64Binary) {
    let $path := xmldb:store($config:packages-col, $xar-filename, $xar-binary)
    let $publish := scanrepo:publish-package($xar-filename)
    return
        map { 
            "files": array {
                map { 
                    "name": $xar-filename,
                    "type": xmldb:get-mime-type($path),
                    "size": xmldb:size($config:packages-col, $xar-filename)
                }   
            }
        }
};

let $xar-filename := request:get-uploaded-file-name("files[]")
let $xar-binary := request:get-uploaded-file-data("files[]")

let $user := request:get-attribute($config:login-domain || ".user")
let $required-group := config:repo-permissions()?group

return
    if (exists($user) and sm:get-user-groups($user) = $required-group) then
        try {
            local:upload-and-publish($xar-filename, $xar-binary),
            local:log-put-package-event($xar-filename)
        } catch * {
            map {
                "result": 
                    map { 
                        "name": $xar-filename,
                        "error": $err:description
                    }
            }
        }
    else
        (
            response:set-status-code(401),
            map {
                "error": "User must be a member of the " || $required-group || " group."
            }
        )
