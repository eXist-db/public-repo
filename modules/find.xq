xquery version "3.1";

(:~
 : Respond to eXist build requests for packages by their package descriptor's abbrev or name 
 : attribute, matching either (1) a minimum eXist version expressed as a SemVer version, or 
 : (2) an EXPath Package version attributes (`version`, `semver`, `semver-min`, and `semver-max`).
 :
 : The parameter name `version` is retained for backward compatibility, even though it's 
 : `versions` in the EXPath Package spec.
 :
 : The `info` parameter can be used for troubleshooting.
 :
 : The `zip` parameter forces the EXPath Package to be returned with a .xar.zip file extension.
 :
 : @see http://expath.org/spec/pkg
 :)

import module namespace app="http://exist-db.org/xquery/app" at "app.xqm";
import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm";
import module namespace versions="http://exist-db.org/apps/public-repo/versions" at "versions.xqm";

declare namespace request="http://exist-db.org/xquery/request";
declare namespace response="http://exist-db.org/xquery/response";

let $abbrev := request:get-parameter("abbrev", ())
let $name := request:get-parameter("name", ())
let $exist-version-semver := request:get-parameter("processor", $config:default-exist-version)
let $versions := request:get-parameter("version", ())
let $semver := request:get-parameter("semver", ())
let $semver-min := request:get-parameter("semver-min", ())
let $semver-max := request:get-parameter("semver-max", ())
let $zip := request:get-parameter("zip", ())
let $info := request:get-parameter("info", ())
let $app-root-absolute-url := request:get-parameter("app-root-absolute-url", ())

let $packages :=
    if ($name) then
        doc($config:package-groups-doc)//package-group[name eq $name]//package
    else
        doc($config:package-groups-doc)//package-group[abbrev eq $abbrev]//package

let $package := 
    if (exists($versions) or exists($semver) or exists($semver-min) or exists($semver-max)) then
        versions:get-newest-package-satisfying-version-attributes($packages, $versions, $semver, $semver-min, $semver-max)
    else
        versions:get-newest-package-satisfying-exist-version($packages, $exist-version-semver)

return
    if ($package) then
        (: TODO shouldn't we get $abs-public from $config? - joewiz :)
        let $abs-public := $app-root-absolute-url || "/public/"
        let $xar-filename := $package/@path
        return
            if ($info) then
                element found {
                    $package/@sha256, 
                    $package/version ! attribute version {.},
                    $package/@path
                }
            else if ($zip) then
                app:redirect-to($abs-public || $xar-filename || ".zip")
            else
                app:redirect-to($abs-public || $xar-filename)
    else 
        (
            response:set-status-code(404),
            <p>Package file not found!</p>
        )
