xquery version "3.1";

(:~
 : A library module for finding packages by version number criteria
 :)

module namespace versions="http://exist-db.org/apps/public-repo/versions";

import module namespace semver="http://exist-db.org/xquery/semver";


(:~
 : Find all packages compatible with a specific version of eXist (or higher)
 :)
declare function versions:find-compatible-packages(
    $packages as element(package)+, 
    $exist-version-semver as xs:string
) as element(package)* {
    versions:find-compatible-packages($packages, $exist-version-semver, (), (), (), ())
};

(:~
 : Find all packages compatible with a specific version of eXist (or higher) and other version number criteria
 :
 : TODO: find packages with version, semVer, or min/max attributes to test those conditions - joewiz
 :)
declare function versions:find-compatible-packages(
    $packages as element(package)+,
    $exist-version-semver as xs:string, 
    $version as xs:string?, 
    $semVer as xs:string?, 
    $min as xs:string?, 
    $max as xs:string?
) as element(package)* {
    for $package in $packages
    return
        if ($semVer) then
            versions:find-version($packages, $semVer, $semVer)
        else if ($version) then
            $packages[version = $version]
        else if ($min or $max) then
            versions:find-version($packages, $min, $max)
        else if 
            (
                $exist-version-semver and
                versions:is-newer-or-same($exist-version-semver, $package/requires/@semver-min) and
                versions:is-older-or-same($exist-version-semver, $package/requires/@semver-max)
            ) then
            $package
        else
            ()
};

declare 
    %private
function versions:is-newer-or-same($version1 as xs:string, $version2 as xs:string?) {
    empty($version2) or semver:ge($version1, $version2, true())
};

declare
    %private
function versions:is-older-or-same($version1 as xs:string, $version2 as xs:string?) {
    empty($version2) or semver:le($version1, $version2, true())
};

declare
    %private
function versions:find-version($packages as element(package)*, $minVersion as xs:string?, $maxVersion as xs:string?) {
    let $minVersion := if ($minVersion) then $minVersion else "0"
    let $maxVersion := if ($maxVersion) then $maxVersion else "9999"
    return
        versions:find-version($packages, $minVersion, $maxVersion, ())
};

declare 
    %private
function versions:find-version($packages as element(package)*, $minVersion as xs:string, $maxVersion as xs:string, $newest as element()?) {
    if (empty($packages)) then
        $newest
    else
        let $package := head($packages)
        let $packageVersion := $package/version | $package/@version
        let $newer :=
            if (
                (
                    empty($newest) or 
                    versions:is-newer($packageVersion, ($newest/version, $newest/@version))
                ) and
                versions:is-newer($packageVersion, $minVersion) and
                versions:is-older($packageVersion, $maxVersion)
            ) then
                $package
            else
                $newest
        return
            versions:find-version(tail($packages), $minVersion, $maxVersion, $newer)
};

declare 
    %private 
function versions:is-newer($available as xs:string, $installed as xs:string) as xs:boolean {
    let $verInstalled := tokenize($installed, "\.")
    let $verAvailable := tokenize($available, "\.")
    return
        versions:compare-versions(
            $verInstalled, 
            $verAvailable, 
            function($version1, $version2) {
                number($version1) >= number($version2)
            }
        )
};

declare 
    %private 
function versions:is-older($available as xs:string, $installed as xs:string) as xs:boolean {
    let $verInstalled := tokenize($installed, "\.")
    let $verAvailable := tokenize($available, "\.")
    return
        versions:compare-versions(
            $verInstalled, 
            $verAvailable, 
            function($version1, $version2) {
                number($version1) <= number($version2)
            }
        )
};

declare 
    %private 
function versions:compare-versions($installed as xs:string*, $available as xs:string*, $compare as function(*)) as xs:boolean {
    if (empty($installed)) then
        exists($available)
    else if (empty($available)) then
        false()
    else if (head($available) = head($installed)) then
        if (count($available) = 1 and count($installed) = 1) then
            true()
        else
            versions:compare-versions(tail($installed), tail($available), $compare)
    else
        $compare(head($available), head($installed))
};
