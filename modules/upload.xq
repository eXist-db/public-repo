xquery version "3.0";

import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm";
import module namespace scanrepo="http://exist-db.org/xquery/admin/scanrepo" at "scan.xqm";

declare namespace json="http://www.json.org";

declare option exist:serialize "method=json media-type=application/json";

declare function local:upload-and-publish($xar as xs:string, $data) {
    let $path := xmldb:store($config:public, $xar, $data)
    let $scan := scanrepo:publish($xar)

    return
        <result>
            <files json:array="true">
               <name>{$path}</name>
               <type>{xmldb:get-mime-type($path)}</type>
               <size>{xmldb:size($config:public, $xar)}</size>
            </files>
       </result>
};

let $name := request:get-uploaded-file-name("files[]")
let $data := request:get-uploaded-file-data("files[]")

return
    try {
        local:upload-and-publish($name, $data)
    } catch * {
        <result>
           <name>{$name}</name>
           <error>{$err:description}</error>
        </result>
    }
