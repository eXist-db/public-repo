xquery version "1.0";

import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm";

declare namespace repo="http://exist-db.org/xquery/repo";
declare namespace expath="http://expath.org/ns/pkg";

declare function local:entry-data($path as xs:anyURI, $type as xs:string, $data as item()?, $param as item()*) as item()*
{
    if (starts-with($path, "icon")) then
        let $pkgName := substring-before($param, ".xar")
        let $suffix := replace($path, "^.*\.([^\.]+)", "$1")
        let $name := concat($pkgName, ".", $suffix)
        let $stored :=
            xmldb:store($config:public, $name, $data)
        return
            <icon>{ $name }</icon>
    else
        let $root := $data/*
        return
            typeswitch ($root)
                case element(expath:package) return (
                    <title>{$root/expath:title/text()}</title>,
                    <abbrev>{$root/@abbrev/string()}</abbrev>,
                    <version>{$root/@version/string()}</version>
                )
                case element(repo:meta) return (
                    for $author in $root/repo:author
                    return
                        <author>{$author/text()}</author>,
                    <description>{$root/repo:description/text()}</description>,
                    <website>{$root/repo:website/text()}</website>,
                    <license>{$root/repo:license/text()}</license>
                )
                default return
                    ()
};

declare function local:entry-filter($path as xs:anyURI, $type as xs:string, $param as item()*) as xs:boolean
{
	starts-with($path, "icon") or $path = ("repo.xml", "expath-pkg.xml")
};

declare function local:extract-metadata($resource as xs:string) {
    let $xar := concat($config:public, "/", $resource)
    return
        <app path="{$resource}">
        {
            compression:unzip(util:binary-doc($xar), util:function(xs:QName("local:entry-filter"), 3), (),  
                util:function(xs:QName("local:entry-data"), 4), $resource)
        }
        </app>
};

declare function local:scan() {
    for $resource in xmldb:get-child-resources($config:public)
    where ends-with($resource, ".xar")
    return
        local:extract-metadata($resource)
};

let $data := <apps>{ local:scan() }</apps>
return
    xmldb:store($config:public, "apps.xml", $data)