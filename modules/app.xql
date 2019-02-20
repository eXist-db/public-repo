xquery version "3.0";

module namespace app="http://exist-db.org/xquery/app";

import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm";
import module namespace scanrepo="http://exist-db.org/xquery/admin/scanrepo" at "scan.xql";

declare function app:publish($node as node(), $model as map(*), $publish as xs:boolean?) {
    if ($publish) then
        scanrepo:scan()
    else
        ()
};

declare function app:list-packages($node as node(), $model as map(*), $mode as xs:string?) {
    for $app in collection($config:public)//app
    let $show-details := false()
    order by lower-case($app/title)
    return
        app:package-to-list-item($app, $show-details)
};

declare function app:view-package($node as node(), $model as map(*), $mode as xs:string?) {
    let $abbrev := request:get-parameter("abbrev", ())
    let $procVersion := request:get-parameter("eXist-db-min-version", "2.2.0")
    let $matching-abbrev := collection($config:public)//abbrev[. eq $abbrev]
    let $app := $matching-abbrev/parent::app
    return
        (: catch requests for a package using its legacy "abbrev" and redirect
         : them to a URL using the app's current abbrev, to encourage use of the
         : current abbrev :)
        if ($matching-abbrev/@type eq "legacy") then
            let $current-abbrev := $app/abbrev[not(@type eq "legacy")]
            let $repoURL := concat(substring-before(request:get-uri(), "public-repo/"), "public-repo/")
            let $required-exist-version := $app/requires[@processor eq "http://exist-db.org"]/(@version, @semver-min)[1]
            let $info-url :=
                concat($repoURL, "packages/", $current-abbrev, ".html",
                    if ($required-exist-version) then
                        concat("?eXist-db-min-version=", $required-exist-version)
                    else
                        ()
                )
            return
                response:redirect-to(xs:anyURI($info-url))
        (: view current package info :)
        else
            let $app-versions := ($app, $app/other/version)
            let $compatible-xar := app:find-version($app-versions, $procVersion, (), (), (), ())
            let $package := $app-versions[@path eq $compatible-xar]
            let $show-details := true()
            return
                app:package-to-list-item($package, $show-details)
};

declare function app:package-to-list-item($app as element(app), $show-details as xs:boolean) {
    let $repoURL := concat(substring-before(request:get-uri(), "public-repo/"), "public-repo/")
    let $icon :=
        if ($app/icon) then
            if ($app/@status) then
                $app/icon[1]
            else
                $repoURL || "public/" || $app/icon[1]
        else
            $repoURL || "resources/images/package.png"
    let $download-url := concat($repoURL, "public/", $app/@path)
    let $required-exist-version := $app/requires[@processor eq "http://exist-db.org"]/(@version, @semver-min)[1]
    let $info-url :=
        concat($repoURL, "packages/", $app/abbrev[not(@type eq "legacy")], ".html",
            if ($required-exist-version) then
                concat("?eXist-db-min-version=", $required-exist-version)
            else
                ()
        )
    return
        <li class="package {$app/type}">
            <div class="packageIconArea">
                <a href="{$info-url}"><img class="appIcon" src="{$icon}"/></a>
            </div>
            {
                switch ($app/type)
                    case ("application") return
                        <img src="{$repoURL || "resources/images/app.gif"}" class="ribbon" alt="application" title="This is an application"/>
                    case ("library") return
                        <img src="{$repoURL || "resources/images/library2.gif"}" class="ribbon" alt="library" title="This is a library"/>
                    case ("plugin") return
                        <img src="{$repoURL || "resources/images/plugin2.gif"}" class="ribbon" alt="plugin" title="This is a plugin"/>
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
                                <td>eXist-db { if ($app/requires) then app:requires-to-english($app/requires) else () }</td>
                            </tr>
                        else
                            ()
                        }
                        <tr>
                            <th>Short Title:</th>
                            <td>{ $app/abbrev[not(@type)]/text() }</td>
                        </tr>
                        <tr>
                            <th>Package Name (URI):</th>
                            <td>{ $app/name/string() }</td>
                        </tr>
                        <tr>
                            <th>Author(s):</th>
                            <td>{string-join($app/author, ", ")}</td>
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
                                        let $versions := 
                                            for $version in $app/other/version 
                                            order by $version/@version 
                                            return $version
                                        for $version at $n in $versions
                                        let $download-version-url := concat($repoURL, "public/", $version/@path)
                                        return
                                            (
                                            <a href="{$download-version-url}">{$version/@version/string()}</a>
                                            ,
                                            if ($n lt count($versions)) then ", " else ()
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
                                order by $version descending
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
                        Version {$app/version/text()} {
                            if ($app/requires) then
                                concat(" (Requires eXist-db ", app:requires-to-english($app/requires), ".)")
                            else
                                ()
                            }
                        <br/>
                        Read <a href="{$info-url}">more information</a>, or download <a href="{$download-url}" title="click to download package">{$app/@path/string()}</a>.
                    </p>
            }
        </li>
};

declare function app:find-version($apps as element()*, $procVersion as xs:string, $version as xs:string?, $semVer as xs:string?, $min as xs:string?, $max as xs:string?) {
    if (empty($apps)) then
        ()
    else
        if ($semVer) then
            scanrepo:find-version($apps, $semVer, $semVer)/@path
        else if ($version) then
            $apps[version = $version]/@path | $apps[@version = $version]/@path
        else if ($min or $max) then
            scanrepo:find-version($apps, $min, $max)/@path
        else
            scanrepo:find-newest($apps, (), $procVersion)/@path
};

declare function app:requires-to-english($requires as element()) {
    (: we assume @processor="http://exist.db-org/" :)
    if ($requires/@version) then
        concat(" version ", $requires/@version)
    else if ($requires/@semver) then
        concat(" version ", $requires/@semver)
    else if ($requires/@semver-min) then
        concat(" version ", $requires/@semver-min, " or later")
    else if ($requires/@semver-max) then
        concat(" version ", $requires/@semver-max, " or earlier")
    else
        " version 2.2"
};
