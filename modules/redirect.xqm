xquery version "3.1";

(:~
 : Helper functions to work around limitations in the response
 : module.
 :)
module namespace redirect="http://exist-db.org/xquery/lib/redirect";


(:~
 : signal to the client that the resource was moved permanently 
 :)
declare function redirect:permanent ($location as xs:string) {
    response:set-status-code(301),
    response:set-header("Location", $location)
};

(:~
 : Version of response:redirect-to#1 that is not affected by
 : https://github.com/eXist-db/exist/issues/4249
 :)
declare function redirect:found ($location as xs:string) {
    response:set-status-code(302),
    response:set-header("Location", $location)
};

(:~
 : signal to the client that the resource was moved temporarily 
 :)
declare function redirect:temporary ($location as xs:string) {
    response:set-status-code(307),
    response:set-header("Location", $location)
};
