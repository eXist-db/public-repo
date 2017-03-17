# public-xar-repo

eXist Public Application Repository

This application allows an eXist-db instance to host a repository of applications and libraries stored in the EXPath Package format. Other eXist-db clients can configure their Dashboard (click on the gear icon beneath the eXist-db icon, and you will see a field, "Public Repository URL"), and can then browse available packages via Dashboard > Package Manager. 

The application:

- Displays the list of packages as HTML for browsing/downloading by users
- Exposes a package listing API to eXist-db clients via their Dashboard > Package Manager.
- Exposes an atom feed with all package updates
- Allows administrators to log in, upload new packages, and refresh the package metadata

By default, eXist-db's Dashboard > Package Manager is configured to access the eXist-db Public Application Repository at http://demo.exist-db.org/exist/apps/public-repo/index.html.
