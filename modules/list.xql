xquery version "3.0";

declare namespace list="http://exist-db.org/apps/public-repo/list";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm";
import module namespace semver = "http://exist-db.org/xquery/semver";

declare option output:method "xml";
declare option output:media-type "application/xml";

(: The default version number here is assumed when a client does not send a version parameter.
   It is set to 2.2.0 because this version was the last one known to work with most older packages
   before packages began to declare their version constraints in their package metadata.
   So this should stay as 2.2.0 until we (a) no longer have 2.2-era clients or (b) no longer have
   packages that we care to offer compatibility with 2.2.
 :)
declare variable $list:DEFAULT_VERSION := "2.2.0";

declare function list:is-newer-or-same($version1 as xs:string, $version2 as xs:string?) {
    empty($version2) or
        semver:ge($version1, $version2, true())
};

declare function list:is-older-or-same($version1 as xs:string, $version2 as xs:string?) {
    empty($version2) or
        semver:le($version1, $version2, true())
};

declare function list:get-app($app as element(), $version as xs:string) {
    if ($app/requires) then
        let $min := $app/requires/@semver-min
        let $max := $app/requires/@semver-max
        return
            if ($min or $max) then
                if (list:is-newer-or-same($version, $app/requires/@semver-min) and
                    list:is-older-or-same($version, $app/requires/@semver-max)) then
                    $app
                else
                    (: get older version :)
                    list:versions($app, $version)
            else
                $app
    else
        $app
};

declare function list:versions($app as element(), $version as xs:string) {
    let $v := list:find-version($app/other/version, $version)
    return
        if ($v) then
            <app path="{$v/@path}">
                { $app/@* except $app/@path }
                <version>{ $v/@version/string() }</version>
                { $app/* except $app/version }
            </app>
        else
            ()
};

declare function list:find-version($versions as element()*, $version as xs:string) {
    if (empty($versions)) then
        ()
    else
        let $v := head($versions)
        let $req := $v/requires
        return
            if (list:is-newer-or-same($version, $req/@semver-min) and
                list:is-older-or-same($version, $req/@semver-max)) then
                $v
            else
                list:find-version(tail($versions), $version)
};

let $version := request:get-parameter("version", $list:DEFAULT_VERSION)
let $version := if (matches($version, "^\d+\.\d+\.\d+-?.*$")) then $version else $list:DEFAULT_VERSION

return
    <apps version="{$version}">
    {
        for $app in doc($config:apps-meta)//app
        return
            list:get-app($app, $version)
    }
    </apps>
