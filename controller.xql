xquery version "1.0";

declare variable $exist:path external;
declare variable $exist:resource external;

if ($exist:path eq "/") then
    (: forward root path to index.xql :)
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <redirect url="index.html"/>
    </dispatch>

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
            <forward url="modules/view.xql"/>
        </view>
    </dispatch>

else if ($exist:resource = "find" or ends-with($exist:resource, ".zip")) then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="modules/find.xql"/>
    </dispatch>
    
else if ($exist:resource = "feed.xml") then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="modules/feed.xql"/>
    </dispatch>
    
(: paths starting with /libs/ will be loaded from the webapp directory on the file system :)
else if (starts-with($exist:path, "/libs/")) then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="/{substring-after($exist:path, 'libs/')}" absolute="yes"/>
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