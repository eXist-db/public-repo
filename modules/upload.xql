xquery version "3.0";

import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm";

declare namespace json="http://www.json.org";

declare option exist:serialize "method=json media-type=application/json";

declare function local:upload($collection, $path, $data) {
    let $path := xmldb:store($collection, $path, $data)
    let $upload :=
        <result>
            <files json:array="true">
               <name>{$path}</name>
               <type>{xmldb:get-mime-type($path)}</type>
               <size>93928</size>
            </files>
       </result>
    return
        $upload
};

let $name := request:get-uploaded-file-name("files[]")
let $data := request:get-uploaded-file-data("files[]")
return
    try {
        local:upload($config:public, $name, $data)
    } catch * {
        <result>
           <name>{$name}</name>
           <error>{$err:description}</error>
        </result>
    }