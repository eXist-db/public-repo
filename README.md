# Expath Package Registry

eXist Public Application Repository (public-repo)

This application allows an eXist-db instance to host a repository of applications and libraries stored in the [EXPath Package format](https://expath.org/spec/pkg). Other eXist-db clients can browse available packages via Dashboard > Package Manager.

The application:

- Displays the list of packages as HTML for browsing/downloading by users
- Exposes a package listing API to eXist-db clients via their Dashboard > Package Manager
- Exposes an Atom feed with all package updates
- Allows administrators to log in, upload new packages, and refresh the package metadata

By default, eXist-db's Dashboard > Package Manager is configured to access the eXist-db Expath Package Registry at https://exist-db.org/exist/apps/public-repo.
