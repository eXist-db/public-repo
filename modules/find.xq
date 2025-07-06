xquery version "3.1";

(:~
 : Respond to eXist build requests for packages by their package descriptor's abbrev or name 
 : attribute, matching either (1) a minimum eXist version expressed as a SemVer version, or 
 : (2) an EXPath Package version attributes (`version`, `semver`, `semver-min`, and `semver-max`).
 :
 : The parameter name `version` is retained for backward compatibility, even though it's 
 : `versions` in the EXPath Package spec.
 :
 : The `info` parameter can be used for troubleshooting and to query package availability
 :
 : The `zip` parameter forces the EXPath Package to be returned with a .xar.zip file extension.
 :
 : A client can set application/json in its accept header to receive packge information and errors
 : as JSON.
 :
 : @see http://expath.org/spec/pkg
 :)

import module namespace redirect="http://exist-db.org/xquery/lib/redirect" at "redirect.xqm";
import module namespace versions="http://exist-db.org/apps/public-repo/versions" at "versions.xqm";
import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm";

declare namespace request="http://exist-db.org/xquery/request";
declare namespace response="http://exist-db.org/xquery/response";

(: TODO shouldn't we get $abs-public from $config? - joewiz :)
declare variable $app-root-absolute-url := request:get-parameter("app-root-absolute-url", ());
declare variable $abs-public := $app-root-absolute-url || "/public/";

declare variable $exist-version-semver := request:get-parameter("processor", $config:default-exist-version);
declare variable $abbrev := request:get-parameter("abbrev", ());
declare variable $name := request:get-parameter("name", ());
declare variable $versions := request:get-parameter("version", ());
declare variable $semver := request:get-parameter("semver", ());
declare variable $semver-min := request:get-parameter("semver-min", ());
declare variable $semver-max := request:get-parameter("semver-max", ());

declare variable $zip := request:get-parameter("zip", ());
declare variable $info := request:get-parameter("info", ());

declare variable $versions-or-version-range :=
        exists($versions)
        or exists($semver)
        or exists($semver-min)
        or exists($semver-max)
;

(:~
 : Read and split accept header into a list of mime types, if present
 : q-values are ignored, order is preserved
 :
 : input: "text/html, application/xhtml+xml, application/xml;q=0.9, image/webp, */*;q=0.8"
 : output: ("text/html", "application/json", "application/xml", "image/webp", "*/*")
 :)
declare function local:parse-accept-header() as xs:string* {
    if (request:get-header-names() = "Accept") then (
        tokenize(request:get-header("Accept"), ",")
            ! normalize-space() (: trim value :)
            ! tokenize(., ";")[1] (: drop q :)
    ) else ()
};

declare function local:prefers-json($mime-types as xs:string*) as xs:boolean {
    let $json-index := index-of($mime-types, "application/json")
    let $xml-index := index-of($mime-types, "application/xml")
    return
        exists($json-index) and (empty($xml-index) or $xml-index > $json-index)
};

declare variable $json-preferred := local:prefers-json(local:parse-accept-header());

declare function local:render-semver-range($semver as xs:string?, $semver-min as xs:string?, $semver-max as xs:string?) as xs:string {
    if (exists($semver)) then (
        $semver
    ) else (
        string-join((
            if (exists($semver-min)) then ``[>=`{$semver-min}`]`` else (),
            if (exists($semver-max)) then``[<=`{$semver-max}`]`` else ()
        ))
    )
};

declare function local:report-not-found ($message as xs:string) as item() {
    response:set-status-code(404),
    if ($json-preferred) then (
        response:set-header("content-type", "application/json"),
        serialize(map { "error": $message }, map{ "method": "json" })
    ) else (
        (: could be changed to <error/> element :)
        <p>{$message}</p>
    )
};

declare function local:render-version-query() as xs:string {
    if (exists($versions))
    then ("versions: " || string-join($versions, ', '))
    else if ($versions-or-version-range)
    then ("semver-range: " || local:render-semver-range($semver, $semver-min, $semver-max))
    else ("compatible with processor version " || $exist-version-semver)
};

declare function local:render-package-query() as xs:string {
    if (exists($name)) then (
        "name: " || $name
    ) else (
        "abbrev: " || $abbrev
    )
};

declare variable $packages :=
    if (exists($name)) then (
        doc($config:package-groups-doc)//package-group[name eq $name]//package
    ) else (
        doc($config:package-groups-doc)//package-group[abbrev eq $abbrev]//package
    )
;

declare variable $package := 
    try {
        if ($versions-or-version-range) then (
            versions:get-newest-package-satisfying-version-attributes(
                $packages, $versions, $semver, $semver-min, $semver-max)
        ) else (
            versions:get-newest-package-satisfying-exist-version($packages, $exist-version-semver)
        )
    } catch * {
        util:log("info", "Error retrieving matching package in find.xq: " || $err:description)
    }
;

(: util:log("info", map {
    "exist-version-semver" : $exist-version-semver,
    "abbrev" : $abbrev,
    "name" : $name,
    "versions" : $versions,
    "semver" : $semver,
    "semver-min" : $semver-min,
    "semver-max" : $semver-max,
    "zip" : $zip,
    "info" : $info,
    "json-preferred": $json-preferred
}), :)
if (empty($packages)) then (
    local:report-not-found(``[No package with `{local:render-package-query()}` found.]``)
) else if (empty($package)) then (
    local:report-not-found(
        ``[No matching version found for `{local:render-package-query()}`; `{local:render-version-query()}`.]``)
) else if ($info and $json-preferred) then (
    response:set-header("content-type", "application/json"),
    serialize(
        map {
            "sha256" : string($package/@sha256),
            "path" : string($package/@path),
            "size" : xs:integer($package/@size),
            "name" : string($package/name),
            "abbrev" : string($package/abbrev),
            "version" : string($package/version),
            "url" : $abs-public || $package/@path
        },
        map { "method": "json" }
    )
) else if ($info) then (
    element found {
        $package/@sha256,
        $package/@path,
        $package/@size,
        attribute name { $package/name },
        attribute abbrev { $package/abbrev },
        attribute version { $package/version },
        attribute url { $abs-public || $package/@path }
    }
) else if ($zip) then (
    redirect:found($abs-public || $package/@path || ".zip")
) else (
    redirect:found($abs-public || $package/@path)
)
