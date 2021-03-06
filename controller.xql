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

login:set-user("org.exist.public-repo.login", (), false()),

if ($exist:path eq "") then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <redirect url="{$app-root-absolute-url}/"/>
    </dispatch>

else if ($exist:path eq "/") then
    (: forward root path to index.xql :)
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <redirect url="{$app-root-absolute-url}/index.html"/>
    </dispatch>

else if ($exist:path eq "/public/apps.xml") then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="{$exist:controller}/modules/list.xq"/>
    </dispatch>

(:  Protected resource: user is required to log in with valid credentials.
    If the login fails or no credentials were provided, the request is redirected
    to the login.html page. :)
else if ($exist:path eq "/admin.html") then
    let $user := request:get-attribute("org.exist.public-repo.login.user")
    return
        if (exists($user) and sm:get-user-groups($user) = config:repo-permissions()?group) then
            <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
                <view>
                    <forward url="{$exist:controller}/modules/view.xq">
                        <set-header name="Cache-Control" value="no-cache"/>
                    </forward>
                </view>
            </dispatch>
        else
            <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
                <forward url="{$exist:controller}/login.html"/>
                <view>
                    <forward url="{$exist:controller}/modules/view.xq">
                        <set-header name="Cache-Control" value="no-cache"/>
                    </forward>
                </view>
            </dispatch>

(:  Protected resource :)
else if ($exist:path eq "/put-package") then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="{$exist:controller}/modules/put-package.xq"/>
    </dispatch>

else if (ends-with($exist:resource, ".html") and starts-with($exist:path, "/packages")) then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="{$exist:controller}/packages.html"/>
        <view>
            <forward url="{$exist:controller}/modules/view.xq">
                <add-parameter name="abbrev" value="{substring-before($exist:resource, '.html')}"/>
            </forward>
        </view>
    </dispatch>
    
else if (ends-with($exist:resource, ".html")) then
    (: the html page is run through view.xq to expand templates :)
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <view>
            <forward url="{$exist:controller}/modules/view.xq">
                <set-header name="Cache-Control" value="no-cache"/>
            </forward>
        </view>
    </dispatch>

else if (contains($exist:path, "/public/") and ends-with($exist:resource, ".xar") or ends-with($exist:resource, ".zip")) then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="{$exist:controller}/modules/get-package.xq">
            <add-parameter name="filename" value="{$exist:resource}"/>
        </forward>
    </dispatch>

else if (contains($exist:path, "/public/") and (ends-with($exist:resource, ".png") or ends-with($exist:resource, ".svg"))) then
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
else if ($exist:path eq "/modules/find.xql") then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <redirect url="{$app-root-absolute-url}/find?{request:get-query-string()}"/>
    </dispatch>

else if ($exist:path eq "/find") then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="{$exist:controller}/modules/find.xq">
            <add-parameter name="app-root-absolute-url" value="{$app-root-absolute-url}"/>
        </forward>
    </dispatch>

else if ($exist:resource eq "feed.xml") then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="{$exist:controller}/modules/feed.xq"/>
    </dispatch>

else if (contains($exist:path, "/$shared/")) then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="/shared-resources/{substring-after($exist:path, '/$shared/')}">
            <set-header name="Cache-Control" value="max-age=3600, must-revalidate"/>
        </forward>
    </dispatch>

else if (contains($exist:path, "/resources/")) then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <set-header name="Cache-Control" value="max-age=3600, must-revalidate"/>
    </dispatch>
    
else
    (: everything else is passed through :)
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <cache-control cache="yes"/>
    </dispatch>
