xquery version "3.1";

module namespace scanrepo="http://exist-db.org/xquery/admin/scanrepo";

import module namespace config = "http://exist-db.org/xquery/apps/config" at "config.xqm";
import module namespace crypto = "http://expath.org/ns/crypto";
import module namespace semver = "http://exist-db.org/xquery/semver";
import module namespace util = "http://exist-db.org/xquery/util";

declare namespace repo="http://exist-db.org/xquery/repo";
declare namespace expath="http://expath.org/ns/pkg";

declare function scanrepo:is-newer-or-same($version1 as xs:string, $version2 as xs:string?) {
    empty($version2) or
        semver:ge($version1, $version2, true())
};

declare function scanrepo:is-older-or-same($version1 as xs:string, $version2 as xs:string?) {
    empty($version2) or
        semver:le($version1, $version2, true())
};

declare function scanrepo:process($apps as element(package)*) {
    for $app in $apps
    order by $app/title
    group by $name := $app/name
    return
        (: Identify newest version of the package; sort previous versions newest to oldest; use SemVer 2.0 rules, coercing where needed :)
        let $versions := $app/version
        let $version-maps := 
            $versions ! map:merge((
                map:entry("semver", semver:coerce(.) => semver:serialize()), 
                map:entry("version", .)
            ))
        let $sorted-semvers := semver:sort($version-maps?semver) => reverse()
        let $sorted-versions := 
            for $semver in $sorted-semvers
            return
                $version-maps[?semver eq $semver]?version/..
        let $newest-version := $sorted-versions => head()
        let $older-versions := $sorted-versions => tail()
        let $abbrevs := distinct-values($app/abbrev)
        return
            <package-group>
                { 
                    $newest-version/@*, 
                    $newest-version/*, 
                    $abbrevs[not(. = $newest-version/abbrev)] ! element abbrev { attribute type { "legacy" }, . }
                }
                <other>
                {
                    for $older in $older-versions
                    let $xar := concat($config:public, "/", $older/@path)
                    let $hash := 
                        util:binary-doc($xar)
                        => util:binary-doc-content-digest("SHA-256")
                        => string()
                    return
                        <version version="{$older/version}">{
                            $older/@path, 
                            attribute size { xmldb:size($config:public, $older/@path) }, 
                            attribute sha256 { $hash }, 
                            $older/requires
                        }</version>
                }
                </other>
            </package-group>
};

declare function scanrepo:find-newest($apps as element()*, $newest as element()?, $procVersion as xs:string?) {
    if (empty($apps)) then
        $newest
    else
        let $app := head($apps)
        let $newer :=
            if ($procVersion and
                not(scanrepo:is-newer-or-same($procVersion, $app/requires/@semver-min) and
                    scanrepo:is-older-or-same($procVersion, $app/requires/@semver-max))) then
                $newest
            else if (empty($newest) or scanrepo:is-newer(($app/version, $app/@version), ($newest/version, $newest/@version))) then
                $app
            else
                $newest
        return
            scanrepo:find-newest(tail($apps), $newer, $procVersion)
};

declare function scanrepo:find-version($apps as element()*, $minVersion as xs:string?, $maxVersion as xs:string?) {
    let $minVersion := if ($minVersion) then $minVersion else "0"
    let $maxVersion := if ($maxVersion) then $maxVersion else "9999"
    return
        scanrepo:find-version($apps, $minVersion, $maxVersion, ())
};

declare %private function scanrepo:find-version($apps as element()*, $minVersion as xs:string, $maxVersion as xs:string, $newest as element()?) {
    if (empty($apps)) then
        $newest
    else
        let $app := head($apps)
        let $appVersion := $app/version | $app/@version
        let $newer :=
            if (
                (empty($newest) or scanrepo:is-newer($appVersion, ($newest/version, $newest/@version))) and
                scanrepo:is-newer($appVersion, $minVersion) and
                scanrepo:is-older($appVersion, $maxVersion)
            ) then
                $app
            else
                $newest
        return
            scanrepo:find-version(tail($apps), $minVersion, $maxVersion, $newer)
};

declare %private function scanrepo:is-newer($available as xs:string, $installed as xs:string) as xs:boolean {
    let $verInstalled := tokenize($installed, "\.")
    let $verAvailable := tokenize($available, "\.")
    return
        scanrepo:compare-versions($verInstalled, $verAvailable, function($version1, $version2) {
            number($version1) >= number($version2)
        })
};

declare %private function scanrepo:is-older($available as xs:string, $installed as xs:string) as xs:boolean {
    let $verInstalled := tokenize($installed, "\.")
    let $verAvailable := tokenize($available, "\.")
    return
        scanrepo:compare-versions($verInstalled, $verAvailable, function($version1, $version2) {
            number($version1) <= number($version2)
        })
};

declare %private function scanrepo:compare-versions($installed as xs:string*, $available as xs:string*,
    $compare as function(*)) as xs:boolean {
    if (empty($installed)) then
        exists($available)
    else if (empty($available)) then
        false()
    else if (head($available) = head($installed)) then
        if (count($available) = 1 and count($installed) = 1) then
            true()
        else
            scanrepo:compare-versions(tail($installed), tail($available), $compare)
    else
        $compare(head($available), head($installed))
};

declare function scanrepo:handle-icon($path as xs:string, $data as item()?, $param as item()*) as element(icon) {
    let $pkgName := substring-before($param, ".xar")
    let $suffix := replace($path, "^.*\.([^\.]+)", "$1")
    let $name := concat($pkgName, ".", $suffix)
    let $stored := xmldb:store($config:icons, $name, $data)
    return
        <icon>{ $name }</icon>
};

declare function scanrepo:handle-expath-package($root as element(expath:package)) as element()* {
    <name>{$root/@name/string()}</name>,
    <title>{$root/expath:title/text()}</title>,
    <abbrev>{$root/@abbrev/string()}</abbrev>,
    <version>{$root/@version/string()}</version>,
    if ($root/expath:dependency[starts-with(@processor, "http://exist-db.org")]) then
        <requires>{ $root/expath:dependency[starts-with(@processor, "http://exist-db.org")]/@* }</requires>
    else
        ()
};

declare function scanrepo:handle-repo-meta($root as element(repo:meta)) as element()+ {
    for $author in $root/repo:author
    return
        <author>{$author/text()}</author>
    ,
    <description>{$root/repo:description/text()}</description>,
    <website>{$root/repo:website/text()}</website>,
    <license>{$root/repo:license/text()}</license>,
    <type>{$root/repo:type/text()}</type>
    ,
    for $note in $root/repo:note
    return
        <note>{$note/text()}</note>
    ,
    <changelog>
    {
        scanrepo:copy-changelog($root/repo:changelog/repo:change)
    }
    </changelog>
};

declare function scanrepo:entry-data($path as xs:anyURI, $type as xs:string, $data as item()?, $param as item()*) as item()*
{
    if (starts-with($path, "icon")) then 
        scanrepo:handle-icon($path, $data, $param)
    else
        let $root := $data/*
        return
            typeswitch ($root)
                case element(expath:package) return
                    scanrepo:handle-expath-package($root)
                case element(repo:meta) return
                    scanrepo:handle-repo-meta($root)
                default return
                    ()
};

declare function scanrepo:copy-changelog($nodes as node()*) {
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

declare function scanrepo:entry-filter($path as xs:anyURI, $type as xs:string, $param as item()*) as xs:boolean {
    starts-with($path, "icon.") or 
    $path = ("repo.xml", "expath-pkg.xml")
};

declare function scanrepo:extract-metadata($resource as xs:string) as element(package) {
    let $xar := concat($config:public, "/", $resource)
    let $data := util:binary-doc($xar)
    let $hash := 
        $data
        => util:binary-doc-content-digest("SHA-256")
        => string()
    return
        <package path="{$resource}" size="{xmldb:size($config:public, $resource)}" sha256="{$hash}">
        {
            compression:unzip(
                $data,
                scanrepo:entry-filter#3, 
                (),
                scanrepo:entry-data#4,
                $resource
            )
        }
        </package>
};

declare function scanrepo:scan-all() {
    for $resource in xmldb:get-child-resources($config:public)
    where ends-with($resource, ".xar")
    return
        scanrepo:extract-metadata($resource)
};

declare function scanrepo:scan() {
    let $data := doc($config:packages-meta)//package
    let $processed := <package-groups>{ scanrepo:process($data) }</package-groups>
    let $store := xmldb:store($config:metadata-collection, $config:apps-doc, $processed)
    return
        $processed
};

declare function scanrepo:rebuild-package-meta() as xs:string {
    xmldb:store($config:metadata-collection, $config:packages-doc,
        <raw-packages>{ scanrepo:scan-all() }</raw-packages>)
};

declare function scanrepo:add-package-meta($meta as element(package)) {
    let $packages := doc($config:packages-meta)/raw-packages
    let $node-to-update := $packages/package[@path = $meta/@path]
    return
        if (exists($node-to-update)) then 
            update replace $node-to-update with $meta
        else 
            update insert $meta into $packages
};

declare function scanrepo:publish($xar as xs:string) {
    let $meta := 
        $xar
        => scanrepo:extract-metadata()
        => scanrepo:add-package-meta()
    return 
        scanrepo:scan()
};
