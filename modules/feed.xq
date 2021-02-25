xquery version "3.1";

(:~
 : Generate an Atom feed of packages, with an entry for the newest version of each package
 :)

import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm";

declare namespace request="http://exist-db.org/xquery/request";
declare namespace util="http://exist-db.org/xquery/util";
declare namespace xmldb="http://exist-db.org/xquery/xmldb";

declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

declare option output:method "xml";
declare option output:media-type "application/atom+xml";

declare function local:add-xhtml-ns($nodes) {
    for $node in $nodes
    return
        if ($node instance of element()) then
            element { QName("http://www.w3.org/1999/xhtml", local-name($node)) } { local:add-xhtml-ns($node/node()) }
        else 
            $node
};

declare function local:feed-entries() {
    let $repoURL := concat(substring-before(request:get-url(), "public-repo/"), "public-repo/")
    for $package-group in doc($config:package-groups-doc)//package-group
    let $newest-package := head($package-group//package)
    let $icon :=
        if ($newest-package/icon) then
            if ($newest-package/@status) then
                $newest-package/icon[1]
            else
                $repoURL || "public/" || $newest-package/icon[1]
        else
            $repoURL || "resources/images/package.png"
    let $required-exist-version := $newest-package/requires[@processor eq $config:exist-processor-name]/(@version, @semver-min)[1]
    let $info-url :=
        concat($repoURL, "packages/", $newest-package/abbrev[not(@type eq "legacy")], ".html",
            if ($required-exist-version) then
                concat("?eXist-db-min-version=", $required-exist-version)
            else
                ()
        )
    let $title := $newest-package/title
    let $version := $newest-package/version
    let $authors := $newest-package/author
    let $description := $newest-package/description
    let $license := $newest-package/license
    let $website := $newest-package/website
    let $has-changelog := $newest-package/changelog/*
    let $changes := 
        if ($has-changelog) then
            for $change in $newest-package/changelog/change
            let $version := $change/@version
            let $comment := local:add-xhtml-ns($change/node())
            return
                (
                <dt xmlns="http://www.w3.org/1999/xhtml">Version { $version/string() }</dt>,
                <dd xmlns="http://www.w3.org/1999/xhtml">{ $comment }</dd>
                )
        else ()
    let $updated := xmldb:last-modified($config:packages-col, $newest-package/@path)
    let $content := 
        <div xmlns="http://www.w3.org/1999/xhtml">
            <div class="icon">
                <img src="{$icon}" alt="{$title}" width="64"/>
            </div>
            <div class="details">
                <dl>
                    <dt>Title:</dt>
                    <dd>{ $title/string() }</dd>
                    <dt>Author(s):</dt>
                    <dd>{ if (exists($authors[. ne ""])) then string-join($authors, ", ") else "(No author provided)"}</dd>
                    <dt>Version:</dt>
                    <dd>{ if ($version ne "") then $version/string() else "(No version information provided)" }</dd>
                    <dt>Description:</dt>
                    <dd>{ if ($description ne "") then $description/string() else "(No description provided)"}</dd>
                    <dt>License:</dt>
                    <dd>{ if ($license ne "") then $license/string() else "(No license specified)" }</dd>
                    <dt>Website:</dt>
                    <dd>{ if ($website/node()) then <a href="{$website}">{ $website/string() }</a> else "(No website provided)" }</dd>
                    <dt>Change Log:</dt>
                    <dd>{ if ($has-changelog) then <dl>{ $changes }</dl> else "(No change log provided)" }</dd>
                </dl>
            </div>
        </div>
    order by $updated
    return
        <entry xmlns="http://www.w3.org/2005/Atom">
            <title>{$title || " " || $version}</title>
            <link href="{$info-url}" />
            <id>{"urn:uuid:" || util:uuid($title || "-" || $version)}</id>
            <updated>{$updated}</updated>
            <content type="xhtml">{$content}</content>
            {
                for $author in $authors
                return
                    <author>
                        <name>{$author/string()}</name>
                    </author>
            }
        </entry>

};

declare function local:feed() {
    let $title := "eXist-db Public Package Repository"
    let $subtitle := "Repository for apps and libraries on eXist-db.org."
    let $self-href := request:get-url()
    let $id := "urn:uuid:" || util:uuid("existdb-public-package-repository-feed")
    let $updated := xmldb:last-modified($config:packages-col, "apps.xml")
    let $feed-entries := local:feed-entries()
    return
        <feed xmlns="http://www.w3.org/2005/Atom">
            <title>{$title}</title>
            <subtitle>{$subtitle}</subtitle>
            <link href="{$self-href}" rel="self" />
            <id>{$id}</id>
            <updated>{$updated}</updated>
            {$feed-entries}
        </feed>
};

local:feed()
