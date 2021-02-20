xquery version "3.1";

import module namespace config="http://exist-db.org/xquery/apps/config" at "modules/config.xqm";
import module namespace login="http://exist-db.org/xquery/login" at "resource:org/exist/xquery/modules/persistentlogin/login.xql";

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
        <redirect url="{request:get-uri()}/"/>
    </dispatch>

else if ($exist:path eq "/") then
    (: forward root path to index.xql :)
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <redirect url="index.html"/>
    </dispatch>

else if ($exist:path eq "/public/apps.xml") then (
    response:set-header('Content-Type', 'application/xml'),
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="{$exist:controller}/modules/list.xq"/>
    </dispatch>
)
else if ($exist:resource eq "update.xql") then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="{$exist:controller}/modules/update.xq"/>
        <view>
            <forward url="{$exist:controller}/index.html"/>
            <forward url="{$exist:controller}/modules/view.xq">
                <set-header name="Cache-Control" value="no-cache"/>
            </forward>
        </view>
    </dispatch>
    
(:  Protected resource: user is required to log in with valid credentials.
    If the login fails or no credentials were provided, the request is redirected
    to the login.html page. :)
else if ($exist:path eq "/admin.html") then
    let $user := request:get-attribute("org.exist.public-repo.login.user")
    return
        if (exists($user) and sm:get-user-groups($user) = "repo") then
            <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
                <view>
                    <forward url="{$exist:controller}/modules/view.xq">
                        <set-header name="Cache-Control" value="no-cache"/>
                    </forward>
                </view>
            </dispatch>
        else
            <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
                <forward url="login.html"/>
                <view>
                    <forward url="{$exist:controller}/modules/view.xq">
                        <set-header name="Cache-Control" value="no-cache"/>
                    </forward>
                </view>
            </dispatch>

else if (ends-with($exist:resource, ".html") and starts-with($exist:path, "/packages")) then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="{concat($exist:controller, '/packages.html')}"/>
        <view>
            <forward url="{concat($exist:controller, '/modules/view.xq')}">
                <add-parameter name="abbrev" value="{substring-before($exist:resource, '.html')}"/>
            </forward>
        </view>
    </dispatch>
    
else if (ends-with($exist:resource, ".html")) then
    (: the html page is run through view.xq to expand templates :)
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <view>
            <forward url="modules/view.xq">
                <set-header name="Cache-Control" value="no-cache"/>
            </forward>
        </view>
    </dispatch>

(: TODO figure out how to turn the absolute path $config:app-data-parent-col 
 : into the relative path needed for the forward directive - joewiz :)
else if (contains($exist:path, "/public/") and ends-with($exist:resource, ".xar")) then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="../../{$config:app-data-col-name}/{$config:packages-col-name}/{$exist:resource}"/>
    </dispatch>

else if (contains($exist:path, "/public/") and (ends-with($exist:resource, ".png") or ends-with($exist:resource, ".svg"))) then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="../../{$config:app-data-col-name}/{$config:icons-col-name}/{$exist:resource}"/>
    </dispatch>

else if (contains($exist:path, "/public/") and ends-with($exist:resource, ".zip")) then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="../modules/download-xar-zip.xq"/>
    </dispatch>

else if ($exist:path eq "/find" or ends-with($exist:resource, ".zip")) then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="modules/find.xq">
            <add-parameter name="app-root-absolute-url" value="{$app-root-absolute-url}"/>
        </forward>
    </dispatch>

else if ($exist:resource eq "feed.xml") then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="modules/feed.xq"/>
    </dispatch>

else if (contains($exist:path, "/$shared/")) then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="/shared-resources/{substring-after($exist:path, '/$shared/')}">
            <set-header name="Cache-Control" value="max-age=3600, must-revalidate"/>
        </forward>
    </dispatch>

else if (contains($exist:path, "/resources/")) then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="{$exist:controller}/resources/{substring-after($exist:path, '/resources/')}">
            <set-header name="Cache-Control" value="max-age=3600, must-revalidate"/>
        </forward>
    </dispatch>
    
else if (ends-with($exist:path, ".xml")) then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <set-header name="Cache-Control" value="no-cache"/>
    </dispatch>

else
    (: everything else is passed through :)
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <cache-control cache="yes"/>
    </dispatch>
