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
    $packages as element(package)*, 
    $exist-version-semver as xs:string
) as element(package)* {
    versions:find-compatible-packages($packages, $exist-version-semver, (), (), (), ())
};

(:~
 : Find all packages compatible with a version of eXist meeting various version criteria
 :
 : TODO: find packages with version, semver, or min/max-version attributes to test those conditions - joewiz
 :)
declare function versions:find-compatible-packages(
    $packages as element(package)*,
    $exist-version-semver as xs:string, 
    $version as xs:string?, 
    $semver as xs:string?, 
    $semver-min as xs:string?, 
    $semver-max as xs:string?
) as element(package)* {
    if ($semver) then
        versions:find-version($packages, $semver, $semver)
    else if ($version) then
        $packages[version = $version]
    else if ($semver-min and $semver-max) then
        versions:find-version($packages, $semver-min, $semver-max)
    else if (exists($exist-version-semver)) then
        for $package in $packages
        return
            if 
                (
                    $exist-version-semver and
                    versions:is-newer-or-same($exist-version-semver, $package/requires/@semver-min) and
                    versions:is-older-or-same($exist-version-semver, $package/requires/@semver-max)
                ) then
                $package
            else
                ()
    else
        ()
};

(:~
 : Find the newest version of packages compatible with a specific version of eXist (or higher)
 :)
declare function versions:find-newest-compatible-package(
    $packages as element(package)*, 
    $exist-version-semver as xs:string
) as element(package)? {
    versions:find-newest-compatible-package($packages, $exist-version-semver, (), (), (), ())
};

(:~
 : Find the newest version of packages compatible with a version of eXist meeting various version criteria
 :)
declare function versions:find-newest-compatible-package(
    $packages as element(package)*,
    $exist-version-semver as xs:string, 
    $version as xs:string?, 
    $semver as xs:string?, 
    $min-version as xs:string?, 
    $max-version as xs:string?
) as element(package)? {
    versions:find-compatible-packages($packages, $exist-version-semver, $version, $semver, $min-version, $max-version)
    => head()
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

