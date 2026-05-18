xquery version "3.1";

(:~
 : Rename stored XAR files to the versioned form "{abbrev}-{version}.xar".
 :
 : Public-repo originally stored uploaded XARs under whatever filename the
 : uploader sent, which let a new upload silently overwrite an existing
 : package when two versions shared a filename (e.g. "myapp.xar"). The
 : publish endpoint now derives the filename from each XAR's expath-pkg.xml
 : descriptor, but existing repositories may still hold files under their
 : original names. This script renames them in place and triggers a rescan.
 :
 : Run as a `repo` group member. Idempotent: files already in the versioned
 : form are left alone.
 :
 : @see https://github.com/eXist-db/public-repo/issues/133
 :)

import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm";
import module namespace scanrepo="http://exist-db.org/xquery/admin/scanrepo" at "scan.xqm";

declare namespace xmldb="http://exist-db.org/xquery/xmldb";
declare namespace util="http://exist-db.org/xquery/util";

declare function local:rename-one($original-name as xs:string) as element(file) {
    let $xar-binary := util:binary-doc($config:packages-col || "/" || $original-name)
    let $versioned-name :=
        try {
            scanrepo:derive-versioned-filename($xar-binary)
        } catch * {
            ()
        }
    return
        if (empty($versioned-name)) then
            element file {
                attribute name { $original-name },
                attribute action { "skipped" },
                attribute reason { "could-not-read-expath-pkg.xml" }
            }
        else if ($original-name eq $versioned-name) then
            element file {
                attribute name { $original-name },
                attribute action { "already-versioned" }
            }
        else if (xmldb:get-child-resources($config:packages-col) = $versioned-name) then
            element file {
                attribute name { $original-name },
                attribute action { "skipped" },
                attribute reason { "target-already-exists" },
                attribute target { $versioned-name }
            }
        else
            let $_rename := xmldb:rename(
                $config:packages-col,
                $original-name,
                $versioned-name
            )
            return
                element file {
                    attribute name { $original-name },
                    attribute action { "renamed" },
                    attribute target { $versioned-name }
                }
};

let $existing :=
    for $name in xmldb:get-child-resources($config:packages-col)[ends-with(., ".xar")]
    order by $name collation "http://www.w3.org/2013/collation/UCA?numeric=yes"
    return $name

let $results := $existing ! local:rename-one(.)

let $renamed := $results[@action = "renamed"]
let $rescan :=
    if (exists($renamed)) then
        scanrepo:rebuild-all-package-metadata()
    else
        ()

return
    element status {
        attribute total { count($existing) },
        attribute renamed { count($renamed) },
        attribute already-versioned { count($results[@action = "already-versioned"]) },
        attribute skipped { count($results[@action = "skipped"]) },
        $results
    }
