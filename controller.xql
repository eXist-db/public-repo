xquery version "3.1";

import module namespace login="http://exist-db.org/xquery/login" at "resource:org/exist/xquery/modules/persistentlogin/login.xql";

import module namespace config="http://exist-db.org/xquery/apps/config" at "modules/config.xqm";

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
    let $user := (
        request:get-attribute($config:login-domain || ".user"),
        sm:id()//sm:username/string()
    )[1]

    return 
        (
            exists($user) and 
            sm:get-user-groups($user) = config:repo-permissions()?group
        )
};

login:set-user($config:login-domain, (), false()),

(: 
 : =============
 : Public routes 
 : =============
 :)

if (request:get-method() eq "GET" and $exist:path eq "") then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <redirect url="{$app-root-absolute-url}/"/>
    </dispatch>

(: Landing page with package listing :)
else if (request:get-method() eq "GET" and $exist:path eq "/") then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="{$exist:controller}/templates/index.html"/>
        <view>
            <forward url="{$exist:controller}/modules/view.xq">
                <set-header name="Cache-Control" value="no-cache"/>
                <add-parameter name="base-url" value="{$app-root-absolute-url}"/>
            </forward>
        </view>
    </dispatch>

else if (request:get-method() eq "GET" and $exist:path eq "/search") then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="{$exist:controller}/templates/search.html"/>
        <view>
            <forward url="{$exist:controller}/modules/view.xq">
                <set-header name="Cache-Control" value="no-cache"/>
                <add-parameter name="base-url" value="{$app-root-absolute-url}"/>
            </forward>
        </view>
    </dispatch>

else if (request:get-method() eq "GET" and $exist:path eq "/list") then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="{$exist:controller}/templates/list.html"/>
        <view>
            <forward url="{$exist:controller}/modules/view.xq">
                <set-header name="Cache-Control" value="no-cache"/>
                <add-parameter name="base-url" value="{$app-root-absolute-url}"/>
                <add-parameter name="top-nav-search" value="yes"/>
            </forward>
        </view>
    </dispatch>


(: List apps for packageservice. See https://github.com/eXist-db/existdb-packageservice/blob/master/modules/packages.xqm#L285-L286. :)
else if (request:get-method() eq "GET" and $exist:path eq "/public/apps.xml") then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="{$exist:controller}/modules/list.xq"/>
    </dispatch>

(: Redirect request for package detail with legacy ".html" extension to new canonical pattern without the extension :)
else if (request:get-method() eq "GET" and starts-with($exist:path, "/packages") and ends-with($exist:resource, ".html")) then
    (: TODO make the redirect issue a 301 :)
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <redirect url="{$app-root-absolute-url}/packages/{substring-before($exist:resource, ".html")}?{request:get-query-string()}"/>
    </dispatch>

(: Serve package detail - without the legacy ".html" extension :)
else if (request:get-method() eq "GET" and starts-with($exist:path, "/packages")) then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="{$exist:controller}/templates/packages.html"/>
        <view>
            <forward url="{$exist:controller}/modules/view.xq">
                <add-parameter name="abbrev" value="{$exist:resource}"/>
                <add-parameter name="base-url" value="{$app-root-absolute-url}"/>
                <add-parameter name="top-nav-search" value="yes"/>
            </forward>
        </view>
    </dispatch>

(: Serve requests for packages as ".xar" or ".zip" :)
else if 
    (
        request:get-method() eq "GET" and
        starts-with($exist:path, "/public/") and
        (
            ends-with($exist:resource, ".xar") or
            ends-with($exist:resource, ".zip")
        )
    ) then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="{$exist:controller}/modules/get-package.xq">
            <add-parameter name="filename" value="{$exist:resource}"/>
        </forward>
    </dispatch>

(: Serve requests for icons in the supported formats :)
else if 
    (
        request:get-method() eq "GET" and
        starts-with($exist:path, "/public/") and
        (
            ends-with($exist:resource, ".png") or
            ends-with($exist:resource, ".svg")
        )
    ) then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="{$exist:controller}/modules/get-icon.xq">
            <add-parameter name="filename" value="{$exist:resource}"/>
        </forward>
    </dispatch>

(: Explicitly handle legacy client requests for modules/find.xql, redirecting it to the find endpoint.
 : Clients that hardcode modules/find.xql include: 
 : - atom-editor-support v1.0.1 and earlier (fixed in https://github.com/eXist-db/atom-editor-support/releases/tag/v1.1.0) --> and thus all versions of existdb-langserver up to and including v1.5.3 and earlier (fixed in https://github.com/wolfgangmm/existdb-langserver/pull/24, not yet released).
 : - existdb-packageservice v1.3.9 and earlier (fixed in https://github.com/eXist-db/existdb-packageservice/releases/tag/v1.3.10) --> and thus all versions of eXist up to and including v5.2.0.
 : - shared-resources v0.8.4 and earlier (fixed in https://github.com/eXist-db/shared-resources/releases/tag/v0.8.5) --> and thus all versions of eXist up to and including v4.7.0.
 :)
else if (request:get-method() eq "GET" and $exist:path eq "/modules/find.xql") then 
    (: TODO make the redirect issue a 301 :)
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <redirect url="{$app-root-absolute-url}/find?{request:get-query-string()}"/>
    </dispatch>

else if (request:get-method() eq "GET" and $exist:path eq "/find") then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="{$exist:controller}/modules/find.xq">
            <add-parameter name="app-root-absolute-url" value="{$app-root-absolute-url}"/>
        </forward>
    </dispatch>

else if (request:get-method() eq "GET" and $exist:path eq "/feed.xml") then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="{$exist:controller}/modules/feed.xq"/>
    </dispatch>


else if (request:get-method() eq "GET" and contains($exist:path, "/resources/")) then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <set-header name="Cache-Control" value="max-age=3600, must-revalidate"/>
    </dispatch>

(: 
 : ================
 : Protected routes 
 : ================ 
 :)

(: User is required to be logged in and member of a specific group. Redirect unauthorized requests to the login page. :)
else if 
    (
        not(local:is-authorized-user()) and 
        $exist:path = ("/admin", "/publish", "/stats")
    ) then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="{$exist:controller}/templates/login.html"/>
        <view>
            <forward url="{$exist:controller}/modules/view.xq">
                <set-header name="Cache-Control" value="no-cache"/>
                <add-parameter name="base-url" value="{$app-root-absolute-url}"/>
            </forward>
        </view>
    </dispatch>

(: Allow authenticated users into admin page :)
else if (request:get-method() = ("GET", "POST") and $exist:path eq "/admin") then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="{$exist:controller}/templates/admin.html"/>
        <view>
            <forward url="{$exist:controller}/modules/view.xq">
                <set-header name="Cache-Control" value="no-cache"/>
                <add-parameter name="base-url" value="{$app-root-absolute-url}"/>
                <add-parameter name="top-nav-search" value="yes"/>
            </forward>
        </view>
    </dispatch>
else if (request:get-method() = ("GET") and $exist:path eq "/stats") then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="{$exist:controller}/templates/stats.html"/>
        <view>
            <forward url="{$exist:controller}/modules/view.xq">
                <add-parameter name="base-url" value="{$app-root-absolute-url}"/>
                <add-parameter name="top-nav-search" value="yes"/>
            </forward>
        </view>
    </dispatch>

(: Accept package uploads at the "/publish" endpoint :)
else if (request:get-method() eq "POST" and $exist:path eq "/publish") then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="{$exist:controller}/modules/publish-package.xq"/>
    </dispatch>

(: 
 : ==============
 : Fallback route 
 : ============== 
 :)

(: Respond with a 404 Not Found error  :)
else
    (
        response:set-status-code(404),
        <data>Not found</data>
    )
