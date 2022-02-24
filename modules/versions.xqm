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
        versions:find-packages-satisfying-exist-version-requirements($packages, $exist-version-semver, $semver-min, $semver-max)
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
        let $packageVersion := ($package/version, $package/@version)[1]
        let $newestVersion := ($newest/version, $newest/@version)[1]
        let $newer :=
            if (
                (
                    empty($newest) or 
                    semver:ge($packageVersion, $newestVersion, true())
                ) and
                semver:ge($packageVersion, $minVersion, true()) and
                semver:le($packageVersion, $maxVersion, true())
            ) then
                $package
            else
                $newest
        return
            versions:find-version(tail($packages), $minVersion, $maxVersion, $newer)
};

(:~
 : Find packages whose eXist version requirements meet the client's eXist version
 : 
 : For example, via app.xqm or list.xq, a client may request the subset of a package's
 : releases that are compatible with eXist 5.3.0. The function examines each release's
 : eXist dependency declarations (if present) and returns all matching packages.
 :)
declare function versions:find-packages-satisfying-exist-version-requirements(
    $packages as element(package)*,
    $exist-version-semver as xs:string, 
    $min-version as xs:string?, 
    $max-version as xs:string?
) as element(package)* {
    for $package in $packages
    let $satisfies-semver-min-requirement := 
        if (exists($package/requires/@semver-min)) then
            semver:ge($exist-version-semver, $package/requires/@semver-min, true())
        else
            true()
    let $satisfies-semver-max-requirement := 
        if (exists($package/requires/@semver-max)) then
            semver:lt($exist-version-semver, $package/requires/@semver-max, true())
        else
            true()
    return
        if ($satisfies-semver-min-requirement and $satisfies-semver-max-requirement) then
            $package
        else
            ()
};
