module namespace app="http://exist-db.org/xquery/app";

import module namespace templates="http://exist-db.org/xquery/templates" at "templates.xql";
import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm";

(:~
 : This function can be called from the HTML templating. It shows which parameters
 : are required for a function to be callable from the templating system. To build 
 : your application, add more functions to this module.
 :)
declare function app:list-packages($node as node(), $params as element(parameters)?, $model as item()*) {
    for $app in collection($config:public)//app
    let $icon :=
        if ($app/icon != "") then
            concat("public/", $app/icon)
        else
            "resources/images/package.png"
    let $link := concat("public/", $app/@path)
    return
        <div class="package">
            <img src="{$icon}" alt="{$app/title}" width="48"/>
            <h3>{$app/title/string()} ({$app/version/string()})</h3>
            <div class="details">
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
                        <td colspan="2" class="download"><a href="{$link}">Download</a></td>
                    </tr>
                </table>
            </div>
        </div>
};