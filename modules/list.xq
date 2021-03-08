xquery version "3.1";

(:~
 : Filter all package groups, returning a list of only the compatible versions.
 : 
 : The format of the results preserves compatibility with the package-repo v1.x API
 :)

import module namespace semver="http://exist-db.org/xquery/semver";

import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm";
import module namespace scanrepo="http://exist-db.org/xquery/admin/scanrepo" at "scan.xqm";
import module namespace versions="http://exist-db.org/apps/public-repo/versions" at "versions.xqm";

declare namespace request="http://exist-db.org/xquery/request";

declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

declare option output:method "xml";
declare option output:media-type "application/xml";

let $exist-version := request:get-parameter("version", ())
let $basic-semver-regex := "^\d+\.\d+\.\d+-?.*$"
let $exist-version-semver := 
    if (matches($exist-version, $basic-semver-regex)) then 
        $exist-version 
    else 
        $config:default-exist-version
return
    element apps { 
        attribute version { $exist-version-semver },
        for $package-group in doc($config:package-groups-doc)//package-group
        let $compatible-packages := versions:find-compatible-packages($package-group//package, $exist-version-semver)
        return
            if (exists($compatible-packages)) then
                let $newest-package := head($compatible-packages)
                let $older-packages := tail($compatible-packages)
                return 
                    element app { 
                        $newest-package/@*, 
                        $newest-package/*,
                        if (exists($older-packages)) then
                            element older {
                                for $package in $older-packages
                                return
                                    element version {
                                        $package/@*, 
                                        $package/requires
                                    }
                            }
                        else
                            ()
                    }
            else
                ()
    }
