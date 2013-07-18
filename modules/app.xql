xquery version "3.0";

module namespace app="http://exist-db.org/xquery/app";

import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm";

declare function app:title($node as node(), $model as map(*), $mode as xs:string?) {
    let $package-id := request:get-parameter('package-id', ())
    let $package := collection($config:public)//app[abbrev = $package-id]
    return
        $package/title/string()
};

declare function app:list-packages($node as node(), $model as map(*), $mode as xs:string?) {
    for $app in collection($config:public)//app
    let $show-details := false()
    order by lower-case($app/title)
    return
        app:package-to-list-item($app, $show-details)
};

declare function app:view-package($node as node(), $model as map(*), $mode as xs:string?) {
    let $package-id := request:get-parameter('package-id', ())
    let $package := collection($config:public)//app[abbrev = $package-id]
    let $show-details := true()
    return
        app:package-to-list-item($package, $show-details)
};

declare function app:package-to-list-item($app as element(app), $show-details as xs:boolean) {
    let $repoURL := concat(substring-before(request:get-uri(), 'public-repo/'), 'public-repo/')
    let $icon :=
        if ($app/icon) then
            if ($app/@status) then
                $app/icon[1]
            else
                $repoURL || "public/" || $app/icon[1]
        else
            $repoURL || "resources/images/package.png"
    let $download-url := concat($repoURL, 'public/', $app/@path)
    let $info-url := concat($repoURL, 'packages/', $app/abbrev, '.html')
    return
        <li class="package {$app/type}">
            <div class="packageIconArea">
                <a href="{$info-url}"><img class="appIcon" src="{$icon}"/></a>
            </div>
            {
                switch ($app/type)
                    case ('application') return
                        <img src="{$repoURL || 'resources/images/app.gif'}" class="ribbon" alt="application" title="This is an application"/>
                    case ('library') return
                        <img src="{$repoURL || 'resources/images/library2.gif'}" class="ribbon" alt="library" title="This is a library"/>
                    case ('plugin') return
                        <img src="{$repoURL || 'resources/images/plugin2.gif'}" class="ribbon" alt="plugin" title="This is a plugin"/>
                    default return ()
            }
            <h3 style="padding-bottom: 0"><a href="{$info-url}">{$app/title/text()}</a></h3>
            {
                if ($show-details) then
                    <table>
                        <tr>
                            <th>Description:</th>
                            <td>{ $app/description/text() }</td>
                        </tr>
                        <tr>
                            <th>Version:</th>
                            <td>{ $app/version/text() }</td>
                        </tr>
                        <tr>
                            <td>Size:</td>
                            <td>{ $app/@size idiv 1024 }k</td>
                        </tr>
                        {
                        if ($app/requires) then
                            <tr>
                                <td class="requires">Requirement:</td>
                                <td>eXist-db {$app/requires/@version/string()}</td>
                            </tr>
                        else
                            ()
                        }
                        <tr>
                            <th>Short Title:</th>
                            <td>{ $app/abbrev/text() }</td>
                        </tr>
                        <tr>
                            <th>Package Name (URI):</th>
                            <td>{ $app/name/string() }</td>
                        </tr>
                        <tr>
                            <th>Author(s):</th>
                            <td>{string-join($app/author, ', ')}</td>
                        </tr>
                        <tr>
                            <th>License:</th>
                            <td>{ $app/license/text() }</td>
                        </tr>
                        {
                            if ($app/website != "") then
                                <tr>
                                    <th>Website:</th>
                                    <td><a href="{$app/website}">{ $app/website/text() }</a></td>
                                </tr>
                            else
                                ()
                        }
                        <tr>
                            <td>Download:</td>
                            <td><a href="{$download-url}" title="click to download package">{$app/@path/string()}</a></td>
                        </tr>
                        {
                            if ($app/other/version) then
                                <tr>
                                    <td>Download older versions:</td>
                                    <td>{
                                        let $versions := $app/other/version 
                                        for $version at $n in $versions
                                        let $download-version-url := concat($repoURL, 'public/', $version/@path)
                                        return
                                            (
                                            <a href="{$download-version-url}">{$version/@version/string()}</a>
                                            ,
                                            if ($n lt count($versions)) then ', ' else ()
                                            )
                                    }</td>
                                </tr>
                            else ()
                        }
                        {
                            if ($app/changelog/change) then
                                (
                                <tr>
                                    <th colspan="2">Change log:</th>
                                </tr>
                                ,
                                for $change in $app/changelog/change
                                let $version := $change/@version/string()
                                let $comment := $change/node()
                                return
                                    <tr>
                                        <td>{$version}</td>
                                        <td>{$comment}</td>
                                    </tr>
                                )
                            else ()
                        }
                    </table>
                else 
                    <p> 
                        {$app/description/text()}
                        <br/>
                        Version {$app/version/text()}
                        <br/>
                        Read <a href="{$info-url}">more information</a>, or download <a href="{$download-url}" title="click to download package">{$app/@path/string()}</a>.
                    </p>
            }
        </li>
};