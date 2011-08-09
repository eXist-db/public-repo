module namespace app="http://exist-db.org/xquery/app";

import module namespace templates="http://exist-db.org/xquery/templates" at "templates.xql";
import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm";

(:~
 : This function can be called from the HTML templating. It shows which parameters
 : are required for a function to be callable from the templating system. To build 
 : your application, add more functions to this module.
 :)
declare function app:list-packages($node as node(), $params as element(parameters)?, $model as item()*) {
    let $ajax := $params/param[@name = "mode"]/@value eq "ajax"
    let $uri := 
        if ($ajax) then
            let $url := request:get-url()
            return
                concat(replace($url, "^(.*)/[^/]+$", "$1"), "/")
        else ()
    for $app in collection($config:public)//app
    let $icon :=
        if ($app/icon != "") then
            concat("public/", $app/icon)
        else
            "resources/images/package.png"
    let $link := concat("public/", $app/@path)
    return
        <div class="package">
            <img class="icon" src="{$uri}{$icon}" alt="{$app/title}" width="48"/>
            <h3>{$app/title/string()} ({$app/version/string()})</h3>
            <div class="details">
                <img class="close-details" src="{$uri}resources/images/close.png" alt="Close" title="Close"/>
                <table>
                    <tr>
                        <th>Title:</th>
                        <td>{ $app/title/text() }</td>
                    </tr>
                    <tr>
                        <th>Author(s):</th>
                        <td>
                            <ul>
                            {
                                for $author in $app/author
                                return
                                    <li>{$author/text()}</li>
                            }
                            </ul>
                        </td>
                    </tr>
                    <tr>
                        <th>Version:</th>
                        <td>{ $app/version/text() }</td>
                    </tr>
                    <tr>
                        <th>Description:</th>
                        <td>{ $app/description/text() }</td>
                    </tr>
                    <tr>
                        <th>License:</th>
                        <td>{ $app/license/text() }</td>
                    </tr>
                    <tr>
                        <th>Website:</th>
                        <td><a href="{$app/website}">{ $app/website/text() }</a></td>
                    </tr>
                    <tr>
                        <td colspan="2" class="download">
                            {
                                if ($ajax) then
                                    <form action="admin.xql" method="POST">
                                        <input type="hidden" name="package-url" value="{$uri}{$link}"/>
                                        <input type="hidden" name="panel" value="repo"/>
                                        <button name="action" value="download">
                                            <img src="{$uri}resources/images/install.png" alt="Install" title="Install"/>
                                        </button>
                                    </form>
                                else
                                    ()
                            }
                            <a href="{$uri}{$link}">
                                <img src="{$uri}resources/images/download.png" alt="Download" title="Download"/>
                            </a>
                        </td>
                    </tr>
                </table>
            </div>
        </div>
};