xquery version "3.1";

(:~
 : Allows download of packages
 :
 : Responds to requests like:
 : - /exist/apps/public-repo/public/eXide-1.0.0.xar
 : - /exist/apps/public-repo/public/eXide-1.0.0.xar.zip
 :)

import module namespace app="http://exist-db.org/xquery/app" at "app.xqm";
import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm";

declare namespace request="http://exist-db.org/xquery/request";
declare namespace response="http://exist-db.org/xquery/response";
declare namespace util="http://exist-db.org/xquery/util";
declare namespace xmldb="http://exist-db.org/xquery/xmldb";

declare function local:log-get-package-event($filename as xs:string) as empty-sequence() {
    let $package := doc($config:raw-packages-doc)//package[@path eq $filename]
    let $today := current-date()
    let $log-doc := config:log-doc($today)
    let $event := 
        element event {
            element dateTime { current-dateTime() },
            element type { "get-package" },
            element package-name { $package/name/string() },
            element package-version { $package/version/string() }
        }
    let $update-log :=
        if (doc-available($log-doc)) then 
            update insert $event into doc($log-doc)/public-repo-log
        else
            ( 
                app:mkcol($config:logs-col, config:log-subcol($today)),
                xmldb:store(config:log-col($today), config:log-doc-name($today), element public-repo-log { $event } )
            )
    return
        ()
};

let $filename := request:get-parameter("filename", ())
let $xar-filename :=
    (: strip .zip from resource name :)
    if (ends-with($filename, ".zip")) then
        replace($filename, ".zip$", "")
    else
        $filename
let $path := $config:packages-col || "/" || $xar-filename
return
    if (util:binary-doc-available($path)) then
        let $xar := util:binary-doc($config:packages-col || "/" || $xar-filename)
        let $log := local:log-get-package-event($filename)
        return
            response:stream-binary($xar, "application/zip")
    else
        (
            response:set-status-code(404),
            <p>Package file not found!</p>
        )
