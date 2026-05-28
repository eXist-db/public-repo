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
    (: Derive a versioned filename to prevent collisions when different versions
     : of a package are uploaded with the same filename.
     : See https://github.com/eXist-db/public-repo/issues/133 :)
    let $versioned-filename := scanrepo:derive-versioned-filename($xar-binary)
    let $path := scanrepo:store($config:packages-col, $versioned-filename, $xar-binary)
    let $publish := scanrepo:publish-package($versioned-filename)
    return
        map {
            "files": array {
                map {
                    "name": $versioned-filename,
                    "type": xmldb:get-mime-type($path),
                    "size": xmldb:size($config:packages-col, $versioned-filename)
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

(: True when the request authenticated via HTTP Basic. CLI clients
 : (xst, packageservice, curl --user) use Basic and cannot be CSRF-forged
 : without the user's password, so they are exempt from the Origin check. :)
declare function local:is-basic-auth() as xs:boolean {
    let $auth := request:get-header("Authorization")
    return exists($auth) and starts-with(lower-case($auth), "basic ")
};

(: Same-origin check for cookie-authenticated state-changing requests.
 : Returns true if the request is exempt (Basic auth) or if the Origin
 : (preferred) or Referer header's scheme+host+port match this server.
 : Returns false otherwise — including when both headers are absent on a
 : cookie-auth request (no header, no trust). :)
declare function local:origin-allowed() as xs:boolean {
    if (local:is-basic-auth()) then
        true()
    else
        let $origin := (request:get-header("Origin"), request:get-header("Referer"))[1]
        let $expected-scheme := if (request:get-scheme() = "https") then "https" else "http"
        let $expected-port := request:get-server-port()
        let $expected-host := request:get-server-name()
        let $default-port := ($expected-scheme = "http" and $expected-port = 80) or
                             ($expected-scheme = "https" and $expected-port = 443)
        let $expected := $expected-scheme || "://" || $expected-host ||
                         (if ($default-port) then "" else ":" || $expected-port)
        return
            exists($origin) and (
                $origin = $expected or
                starts-with($origin, $expected || "/")
            )
};


let $xar-filename := request:get-uploaded-file-name($local:file-upload-parameter-name)
let $xar-binary := request:get-uploaded-file-data($local:file-upload-parameter-name)

return
if (not(local:origin-allowed())) then (
    response:set-status-code(403),
    map {
        "error": "Cross-origin request rejected. Same-origin Origin or Referer header required for cookie-authenticated uploads."
    }
) else if (not(local:user-can-publish())) then (
    response:set-status-code(403),
    map {
        "error": "User must be a member of the " || config:repo-permissions()?group || " group."
    }
) else (
    try {
        let $result := local:upload-and-publish($xar-filename, $xar-binary)
        let $versioned-filename := $result?files?(1)?name
        return (
            $result,
            local:log-put-package-event($versioned-filename)
        )
    } catch * {
        response:set-status-code(500),
        map {
            "result": map {
                "name": request:get-uploaded-file-name($local:file-upload-parameter-name),
                "error": $err:description
            }
        }
    }
)
