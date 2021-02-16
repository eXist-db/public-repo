xquery version "3.0";

import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm";

declare option exist:serialize "method=xml media-type=application/atom+xml";

declare function local:feed-entries() {
    let $repoURL := concat(substring-before(request:get-url(), "public-repo/"), "public-repo/")
    for $app in doc($config:apps-meta)//package-group
    let $icon :=
        if ($app/icon) then
            if ($app/@status) then
                $app/icon[1]
            else
                $repoURL || "public/" || $app/icon[1]
        else
            $repoURL || "resources/images/package.png"
    let $required-exist-version := $app/requires[@processor eq "http://exist-db.org"]/(@version, @semver-min)[1]
    let $info-url :=
        concat($repoURL, "packages/", $app/abbrev[not(@type eq "legacy")], ".html",
            if ($required-exist-version) then
                concat("?eXist-db-min-version=", $required-exist-version)
            else
                ()
        )
    let $title := $app/title
    let $version := $app/version
    let $authors := $app/author
    let $description := $app/description
    let $license := $app/license
    let $website := $app/website
    let $has-changelog := $app/changelog/*
    let $changes := 
        if ($has-changelog) then
            for $change in $app/changelog/change
            let $version := $change/@version
            let $comment := $change/node()
            return
                (
                <dt xmlns="http://www.w3.org/1999/xhtml">Version { $version/string() }</dt>,
                <dd xmlns="http://www.w3.org/1999/xhtml">{ $comment }</dd>
                )
        else ()
    let $updated := xmldb:last-modified($config:public, $app/@path)
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
    let $updated := xmldb:last-modified($config:public, "apps.xml")
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
