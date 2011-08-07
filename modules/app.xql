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
    return
        <div class="package">
            <img src="{$icon}" alt="{$app/title}" width="48"/>
            <h3>{$app/title/string()}</h3>
            <div class="details">
                <table>
                    <tr>
                        <td>Title:</td>
                        <td>{ $app/title/text() }</td>
                    </tr>
                    <tr>
                        <td>Author(s):</td>
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
                        <td>Description:</td>
                        <td>{ $app/description }</td>
                    </tr>
                </table>
            </div>
        </div>
};