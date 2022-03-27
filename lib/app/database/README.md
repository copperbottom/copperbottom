# Copperbottom Database
The database library of the Copperbottom application.

This library is responsible for all object-resource-modelling
(ORM) and mapping between entities and a modular (adapter-based)
database backend driver.

To implement or use a new database backend, simply implement a
new adapter for the database backend (see
[adapters/postgres](adapters/postgres.dart) for an example) and
use it by passing it as the `adapter` parameter to
`CopperbottomDatabase`.

Alternatively (or additionally), add your database type to the
[`prepareAdapter`](https://github.com/copperbottom/copperbottom/blob/master/bin/application.dart#L15) method
in `bin/application.dart` to enable it to be used by the
Copperbottom application through end-user configuration.
