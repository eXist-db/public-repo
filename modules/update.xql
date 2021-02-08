xquery version "1.0";

import module namespace scanrepo="http://exist-db.org/xquery/admin/scanrepo" at "scan.xql";

scanrepo:rebuild-package-meta()
=> scanrepo:scan()

(: $file
=> scanrepo:extract-metadata()
=> scanrepo:add-package-meta()
=> scanrepo:scan() :)
