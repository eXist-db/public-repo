xquery version "3.1";

(:~
 : Receives uploaded packages and immediately publishes them to the package repository
 :)

import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm";
import module namespace log="http://exist-db.org/xquery/app/log" at "log.xqm";
import module namespace scanrepo="http://exist-db.org/xquery/admin/scanrepo" at "scan.xqm";

declare namespace request="http://exist-db.org/xquery/request";
declare namespace sm="http://exist-db.org/xquery/securitymanager";
declare namespace xmldb="http://exist-db.org/xquery/xmldb";

declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

declare option output:method "json";
declare option output:media-type "application/json";

declare variable $local:file-upload-parameter-name := "files[]";

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

declare function local:upload-and-publish($xar-filename as xs:string, $xar-binary as xs:base64Binary) as map(*) {
    let $path := scanrepo:store($config:packages-col, $xar-filename, $xar-binary)
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

declare function local:user-can-publish() as xs:boolean {
    let $user := (
        request:get-attribute($config:login-domain || ".user"),
        sm:id()//sm:username/string()
    )[1]
    return (
        exists($user) and
        sm:get-user-groups($user) = config:repo-permissions()?group
    )
};

let $_ := util:log("info", request:get-parameter-names())

let $xar-filename := request:get-uploaded-file-name($local:file-upload-parameter-name)
let $xar-binary := request:get-uploaded-file-data($local:file-upload-parameter-name)

return
if (not(local:user-can-publish())) then (
    response:set-status-code(403),
    map {
        "error": "User must be a member of the " || config:repo-permissions()?group || " group."
    }
) else (
    try {
        local:upload-and-publish($xar-filename, $xar-binary),
        local:log-put-package-event($xar-filename)
    } catch * {
        map {
            "result": map {
                "name": request:get-uploaded-file-name($local:file-upload-parameter-name),
                "error": $err:description
            }
        }
    }
)
