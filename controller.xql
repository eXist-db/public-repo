xquery version "1.0";

import module namespace login="http://exist-db.org/xquery/login" at "resource:org/exist/xquery/modules/persistentlogin/login.xql";

declare variable $exist:path external;
declare variable $exist:resource external;
declare variable $exist:controller external;

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

else if ($exist:path = "/public/apps.xml") then (
    response:set-header('Content-Type', 'application/xml'),
    
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="{$exist:controller}/modules/list.xql"/>
    </dispatch>
)
else if ($exist:resource = "update.xql") then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="{$exist:controller}/modules/update.xql"/>
        <view>
            <forward url="{$exist:controller}/index.html"/>
            <forward url="{$exist:controller}/modules/view.xql">
                <set-header name="Cache-Control" value="no-cache"/>
            </forward>
        </view>
    </dispatch>
    
(:  Protected resource: user is required to log in with valid credentials.
    If the login fails or no credentials were provided, the request is redirected
    to the login.html page. :)
else if ($exist:resource eq 'admin.html') then (
    let $user := request:get-attribute("org.exist.public-repo.login.user")
    return
        if ($user and (sm:is-dba($user) or "repo" = sm:get-user-groups($user))) then
            <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
                <view>
                    <forward url="{$exist:controller}/modules/view.xql">
                        <set-header name="Cache-Control" value="no-cache"/>
                    </forward>
                </view>
            </dispatch>
        else
            <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
                <forward url="login.html"/>
                <view>
                    <forward url="{$exist:controller}/modules/view.xql">
                        <set-header name="Cache-Control" value="no-cache"/>
                    </forward>
                </view>
            </dispatch>
)

else if (ends-with($exist:resource, ".html") and starts-with($exist:path, "/packages")) then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="{concat($exist:controller, '/packages.html')}"/>
        <view>
            <forward url="{concat($exist:controller, '/modules/view.xql')}">
                <add-parameter name="package-id" value="{substring-before($exist:resource, '.html')}"/>
            </forward>
        </view>
    </dispatch>
    
else if (ends-with($exist:resource, ".html")) then
    (: the html page is run through view.xql to expand templates :)
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <view>
            <forward url="modules/view.xql">
                <set-header name="Cache-Control" value="no-cache"/>
            </forward>
        </view>
    </dispatch>

else if (contains($exist:path, "/public/") and ends-with($exist:resource, ".zip")) then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="../modules/download-xar-zip.xq"/>
    </dispatch>

else if ($exist:resource = "find" or ends-with($exist:resource, ".zip")) then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="modules/find.xql"/>
    </dispatch>
    
else if ($exist:resource = "feed.xml") then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="modules/feed.xql"/>
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
