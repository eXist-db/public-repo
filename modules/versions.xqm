xquery version "3.1";

(:~
 : A library module for finding packages by EXPath Package dependency version attributes 
 : or eXist version
 :)

module namespace versions="http://exist-db.org/apps/public-repo/versions";

import module namespace semver="http://exist-db.org/xquery/semver";


(:~
 : Get all packages satisfying EXPath Package dependency version attributes
 :)
declare function versions:get-packages-satisfying-version-attributes(
    $packages as element(package)*,
    $versions as xs:string?, 
    $semver as xs:string?, 
    $semver-min as xs:string?, 
    $semver-max as xs:string?
) as element(package)* {
    $packages[
        semver:satisfies-expath-package-dependency-versioning-attributes(
            ./version,
            $versions,
            $semver,
            $semver-min,
            $semver-max
        )
    ]
    => versions:sort-packages()
};

(:~
 : Get the newest version of a package satisfying EXPath Package dependency version attributes
 :)
declare function versions:get-newest-package-satisfying-version-attributes(
    $packages as element(package)*,
    $versions as xs:string?, 
    $semver as xs:string?, 
    $semver-min as xs:string?, 
    $semver-max as xs:string?
) as element(package)? {
    $packages
    => versions:get-packages-satisfying-version-attributes($versions, $semver, $semver-min, $semver-max)
    => head()
};

(:~
 : Find all packages compatible with a specific version of eXist (or higher)
 : 
 : For example, via app.xqm or list.xq, a client may request the subset of a package's
 : releases that are compatible with eXist 5.3.0. The function examines each release's
 : eXist dependency declarations (if present) and returns all matching packages.
 :)
declare function versions:get-packages-satisfying-exist-version(
    $packages as element(package)*, 
    $exist-version as xs:string
) as element(package)* {
    $packages[
        semver:satisfies-expath-package-dependency-versioning-attributes(
            $exist-version,
            ./requires/@versions,
            ./requires/@semver,
            ./requires/@semver-min,
            ./requires/@semver-max
        )
        or 
        empty(./requires)
    ]
    => versions:sort-packages()
};

(:~
 : Find the newest version of packages compatible with a specific version of eXist (or higher)
 :)
declare function versions:get-newest-package-satisfying-exist-version(
    $packages as element(package)*, 
    $exist-version-semver as xs:string
) as element(package)? {
    $packages
    => versions:get-packages-satisfying-exist-version($exist-version-semver)
    => head()
};

(:~
 : Sort packages by version, newest to oldest
 :)
declare function versions:sort-packages($packages as element(package)*) {
    semver:sort($packages, function($package) { $package/version }, true())
    => reverse()
};
