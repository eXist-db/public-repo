xquery version "3.1";

(:~
 : Functions to extract metadata from packages and populate, update, or rebuild package metadata files
 :)

module namespace scanrepo="http://exist-db.org/xquery/admin/scanrepo";

import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm";
import module namespace semver="http://exist-db.org/xquery/semver";

declare namespace compression="http://exist-db.org/xquery/compression";
declare namespace repo="http://exist-db.org/xquery/repo";
declare namespace util="http://exist-db.org/xquery/util";
declare namespace xmldb="http://exist-db.org/xquery/xmldb";

declare namespace expath="http://expath.org/ns/pkg";

(:~
 : Helper function to store a package's icon and transform its metadata into the format needed for raw-metadata
 :)
declare 
    %private
function scanrepo:handle-icon($path as xs:string, $data as item()?, $param as item()*) as element(icon) {
    let $pkgName := substring-before($param, ".xar")
    let $suffix := replace($path, "^.*\.([^\.]+)", "$1")
    let $name := concat($pkgName, ".", $suffix)
    let $stored := xmldb:store($config:icons-col, $name, $data)
    return
        element icon { $name }
};

(:~
 : Helper function to transform expath-pkg.xml metadata into the format needed for raw-metadata
 :)
declare 
    %private
function scanrepo:handle-expath-pkg-metadata($root as element(expath:package)) as element()* {
    $root/(@name, expath:title, @abbrev, @version) ! 
        element { local-name(.) } { ./string() },
    $root/expath:dependency[@processor eq $config:exist-processor-name] ! 
        element requires { ./@* }
};

(:~
 : Helper function to transform repo.xml's changelog metadata into the format needed for raw-metadata
 :)
declare 
    %private 
function scanrepo:copy-changelog($nodes as node()*) {
    for $node in $nodes
    return
        typeswitch ($node)
            case element() return
                element { local-name($node) } {
                    $node/@*,
                    scanrepo:copy-changelog($node/node())
                }
            default return
                $node
};

(:~
 : Helper function to transform repo.xml metadata into the format needed for raw-metadata
 :)
declare 
    %private
function scanrepo:handle-repo-metadata($root as element(repo:meta)) as element()+ {
    $root/(repo:author, repo:description, repo:website, repo:license, repo:type, repo:note) ! 
        element { local-name(.) } { ./string() },
    element changelog { scanrepo:copy-changelog($root/repo:changelog/repo:change) }
};

(:~
 : Helper function to handle transformation of icon and package metadata for extraction from the xar
 :)
declare 
    %private
function scanrepo:entry-data($path as xs:anyURI, $type as xs:string, $data as item()?, $param as item()*) as item()*
{
    if (starts-with($path, "icon")) then 
        scanrepo:handle-icon($path, $data, $param)
    else
        let $root := $data/*
        return
            typeswitch ($root)
                case element(expath:package) return
                    scanrepo:handle-expath-pkg-metadata($root)
                case element(repo:meta) return
                    scanrepo:handle-repo-metadata($root)
                default return
                    ()
};

(:~
 : Helper function to select assets from a package for extraction from the xar
 :)
declare 
    %private 
function scanrepo:entry-filter($path as xs:anyURI, $type as xs:string, $param as item()*) as xs:boolean {
    starts-with($path, "icon.") or $path = ("repo.xml", "expath-pkg.xml")
};

(:~
 : Take a group of packages with the same package name (a URI) and generate a package-group
 :)
declare 
(:    %private:)
function scanrepo:generate-package-group($packages as element(package)*) {
    if (count(distinct-values($packages/name)) gt 1) then
        error(QName("scanrepo", "group-error"), "Supplied packages do not have the same name")
    else
        (: Identify newest version of the package; sort previous versions newest to oldest; use SemVer 2.0 rules, coercing where needed :)
        let $versions := $packages/version
        let $version-maps := 
            $versions ! map:merge((
                map:entry("semver", semver:coerce(.) => semver:serialize()), 
                map:entry("version", .)
            ))
        let $sorted-semvers := semver:sort($version-maps?semver) => reverse()
        let $sorted-packages := 
            for $semver in $sorted-semvers
            return
                $version-maps[?semver eq $semver]?version/..
        let $newest-package := $sorted-packages => head()
        let $legacy-abbrevs := distinct-values($packages/abbrev)[not(. = $newest-package/abbrev)]
        return
            element package-group {
                $newest-package/(title, name, abbrev), 
                $legacy-abbrevs ! element abbrev { attribute type { "legacy" }, . },
                element packages { $sorted-packages }
            }
};


(:~
 : Update a package group, creating it if necessary
 :)
declare function scanrepo:update-package-group($raw-package-name as xs:string) {
    let $raw-packages := doc($config:raw-packages-doc)/raw-packages
    let $raw-packages-to-group := $raw-packages/package[name = $raw-package-name]
    let $package-groups := doc($config:package-groups-doc)/package-groups
    let $current-package-group := $package-groups/package-group[name eq $raw-package-name]
    return
        if (exists($current-package-group)) then 
            update replace $current-package-group with scanrepo:generate-package-group($raw-packages-to-group) 
        else 
            update insert scanrepo:generate-package-group($raw-packages-to-group) into $package-groups
};

(:~
 : Add a package's metadata to raw-packages
 :)
declare function scanrepo:add-raw-package($raw-package as element(package)) {
    let $raw-packages := doc($config:raw-packages-doc)/raw-packages
    let $current-raw-package := $raw-packages/package[@path = $raw-package/@path]
    return
        if (exists($current-raw-package)) then 
            update replace $current-raw-package with $raw-package
        else 
            update insert $raw-package into $raw-packages
};

(:~
 : Extract a stored package's raw-package metadata
 :)
declare function scanrepo:extract-raw-package($xar-filename as xs:string) as element(package) {
    let $xar-path := $config:packages-col || "/" || $xar-filename
    let $xar-binary := util:binary-doc($xar-path)
    let $package-metadata :=
        compression:unzip(
            $xar-binary,
            scanrepo:entry-filter#3, 
            (),
            scanrepo:entry-data#4,
            $xar-filename
        )
    return
        element package {
            attribute path { $xar-filename },
            attribute size { xmldb:size($config:packages-col, $xar-filename) },
            attribute sha256 { util:binary-doc-content-digest($xar-path, "SHA-256") => string() },
            $package-metadata
        }
};

(:~
 : Publish a stored package by adding it to the raw-packages and package-groups metadata
 :)
declare function scanrepo:publish-package($xar-filename as xs:string) {
    let $package := scanrepo:extract-raw-package($xar-filename)
    return
        (
            scanrepo:add-raw-package($package),
            scanrepo:update-package-group($package/name)
        )
};

(:~
 : Rebuild the package-groups metadata by merging raw-packages metadata into package-groups
 :)
declare function scanrepo:rebuild-package-groups() as xs:string {
    let $groups :=
        for $package in doc($config:raw-packages-doc)//package
        group by $name := $package/name
        return
            scanrepo:generate-package-group($package)
    let $package-groups := 
        element package-groups { 
            for $group in $groups
            order by $group/abbrev[not(@type = "legacy")]
            return
                $group
        }
    return
        xmldb:store($config:metadata-col, $config:package-groups-doc-name, $package-groups)
};

(:~
 : Rebuild the raw-packages metadata from all stored packages
 :)
declare function scanrepo:rebuild-raw-packages() as xs:string {
    let $raw-packages := 
        element raw-packages { 
            for $package-xar in xmldb:get-child-resources($config:packages-col)[ends-with(., ".xar")]
            order by $package-xar
            return
                scanrepo:extract-raw-package($package-xar)
        }
    return
        xmldb:store($config:metadata-col, $config:raw-packages-doc-name, $raw-packages)
};

(:~
 : Rebuild all package metadata
 :)
declare function scanrepo:rebuild-all-package-metadata() as xs:string+ {
    scanrepo:rebuild-raw-packages(),
    scanrepo:rebuild-package-groups()
};
