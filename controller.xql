xquery version "3.1";

import module namespace config="http://exist-db.org/xquery/apps/config" at "modules/config.xqm";
import module namespace login="http://exist-db.org/xquery/login" at "resource:org/exist/xquery/modules/persistentlogin/login.xql";

declare namespace sm="http://exist-db.org/xquery/securitymanager";

declare variable $exist:path external;
declare variable $exist:resource external;
declare variable $exist:controller external;
declare variable $exist:prefix external;
declare variable $exist:root external;

declare variable $app-root-absolute-url := 
    request:get-context-path()
    || $exist:prefix
    || $exist:controller
;

declare function local:is-authorized-user() as xs:boolean {
    let $user := request:get-attribute($config:login-domain || ".user")
    return (
        exists($user) and 
        sm:get-user-groups($user) = config:repo-permissions()?group
    )
};

login:set-user($config:login-domain, (), false()),
(: public routes :)
if ($exist:path eq "") then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <redirect url="{request:get-uri()}/"/>
    </dispatch>

else if (request:get-method() eq "GET" and $exist:path eq "/") then
    (: forward root path to index.xql :)
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="/{$exist:controller}/index.html"/>
        <view>
            <forward url="/{$exist:controller}/modules/view.xq">
                <set-header name="Cache-Control" value="no-cache"/>
            </forward>
        </view>
    </dispatch>

(: legacy route :)
else if (request:get-method() eq "GET" and $exist:path eq "/public/apps.xml") then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="/{$exist:controller}/modules/list.xq"/>
    </dispatch>

(: package detail with html :)
else if (request:get-method() eq "GET" and ends-with($exist:resource, ".html") and starts-with($exist:path, "/packages")) then
(
    response:set-status-code(301),
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <redirect url="{$app-root-absolute-url}/packages/{substring-before($exist:resource, ".html")}?{request:get-query-string()}"/>
    </dispatch>
)
(: package detail without html :)
else if (request:get-method() eq "GET" and starts-with($exist:path, "/packages")) then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="/{$exist:controller}/packages.html"/>
        <view>
            <forward url="/{$exist:controller}/modules/view.xq">
                <add-parameter name="abbrev" value="{$exist:resource}"/>
            </forward>
        </view>
    </dispatch>

(:
else if (ends-with($exist:resource, ".html")) then
    let $page := substring-before($exist:resource, ".html")
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <view>
            <forward url="{$exist:controller}/modules/view.xq">
                <set-header name="Cache-Control" value="no-cache"/>
            </forward>
        </view>
    </dispatch>
:)

else if (
    request:get-method() eq "GET" and
    contains($exist:path, "/public/") and
    (
        ends-with($exist:resource, ".xar") or
        ends-with($exist:resource, ".zip")
    )
    ) then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="/{$exist:controller}/modules/get-package.xq">
            <add-parameter name="filename" value="{$exist:resource}"/>
        </forward>
    </dispatch>

else if (
    request:get-method() eq "GET" and
    contains($exist:path, "/public/") and
    (
        ends-with($exist:resource, ".png") or
        ends-with($exist:resource, ".svg")
    )
    ) then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="/{$exist:controller}/modules/get-icon.xq">
            <add-parameter name="filename" value="{$exist:resource}"/>
        </forward>
    </dispatch>

(: Explicitly handle legacy client requests for modules/find.xql, redirecting it to the find endpoint.
 : Clients that hardcode modules/find.xql include: 
 : - atom-editor-support v1.0.1 and earlier (fixed in https://github.com/eXist-db/atom-editor-support/releases/tag/v1.1.0) --> and thus all versions of existdb-langserver up to and including v1.5.3 and earlier (fixed in https://github.com/wolfgangmm/existdb-langserver/pull/24, not yet released).
 : - existdb-packageservice v1.3.9 and earlier (fixed in https://github.com/eXist-db/existdb-packageservice/releases/tag/v1.3.10) --> and thus all versions of eXist up to and including v5.2.0.
 : - shared-resources v0.8.4 and earlier (fixed in https://github.com/eXist-db/shared-resources/releases/tag/v0.8.5) --> and thus all versions of eXist up to and including v4.7.0.
 :)
else if ($exist:path eq "/modules/find.xql") then (
    response:set-status-code(301),
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <redirect url="{$app-root-absolute-url}/find?{request:get-query-string()}"/>
    </dispatch>
)
else if (request:get-method() eq "GET" and $exist:path eq "/find") then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="/{$exist:controller}/modules/find.xq">
            <add-parameter name="app-root-absolute-url" value="{$app-root-absolute-url}"/>
        </forward>
    </dispatch>

else if (request:get-method() eq "GET" and $exist:resource eq "feed.xml" or $exist:resource eq "feed" ) then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="/{$exist:controller}/modules/feed.xq"/>
    </dispatch>

else if (request:get-method() eq "GET" and contains($exist:path, "/$shared/")) then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="/shared-resources/{substring-after($exist:path, '/$shared/')}">
            <set-header name="Cache-Control" value="max-age=3600, must-revalidate"/>
        </forward>
    </dispatch>

else if (request:get-method() eq "GET" and contains($exist:path, "/resources/")) then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <set-header name="Cache-Control" value="max-age=3600, must-revalidate"/>
    </dispatch>

(: redirect any unauthorized request to the login page :)
else if (not(local:is-authorized-user()) and 
    ($exist:path eq "/admin" or $exist:path eq "/publish")) then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="login.html"/>
        <view>
            <forward url="{$exist:controller}/modules/view.xq">
                <set-header name="Cache-Control" value="no-cache"/>
            </forward>
        </view>
    </dispatch>

(: 
 : Protected resources:
 : user is required to be logged in and member of a specific group 
 :)
else if (request:get-method() = ("GET", "POST") and $exist:path eq "/admin") then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="admin.html"/>
        <view>
            <forward url="{$exist:controller}/modules/view.xq">
                <set-header name="Cache-Control" value="no-cache"/>
            </forward>
        </view>
    </dispatch>

else if (request:get-method() eq "POST" and $exist:path eq "/publish") then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="{$exist:controller}/modules/put-package.xq"/>
    </dispatch>

(: everything else is a NOT-FOUND error  :)
else
(
    response:set-status-code(404),
    <data>Not found</data>
)