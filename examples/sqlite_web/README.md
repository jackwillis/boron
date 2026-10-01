# SQLite + ActiveRecord + Sinatra in Boron

A small persistent JSON API. The application logic, schema setup, model creation,
and routes are Boron in `app.bn`; `app_test.rb` is a Minitest integration harness.
This optional example lives in the repository and has its own Gemfile. Boron
itself gains no runtime dependencies.

From the repository root:

```sh
cd examples/sqlite_web
BUNDLE_PATH=vendor/bundle bundle install
BUNDLE_PATH=vendor/bundle bundle exec boron run app.bn -- --serve
```

The server binds to `127.0.0.1:4567`. In another terminal:

```sh
curl http://127.0.0.1:4567/health
curl http://127.0.0.1:4567/users
```

`/health` returns `{"status":"ok","users":2}` on the initial database.
`/users` returns Ada and Grace with database IDs. The first start creates the
users table and seeds two rows; subsequent starts preserve existing rows.
Stop with Ctrl+C. Set `BORON_DATABASE=/path/to/demo.sqlite3` to choose the database;
the default is `boron-demo.sqlite3` in the working directory. Loading without
`--serve` initializes the database and app but does not start a server.

Tests, without opening a network port:

```sh
BUNDLE_PATH=vendor/bundle bundle exec ruby app_test.rb
```

Tests use temporary file databases, verify JSON/404 responses, observe database
changes, preserve rows through reloading, and execute emitted Ruby in a fresh
process. The core lint/test commands remain the ones in the repository README.

## Named classes and explicit routes

`defmodule BoronDemo` creates a real Ruby module. `defclass BoronDemo::User <
ActiveRecord::Base` creates and names a real Ruby model class before ActiveRecord
needs its model identity. Both declarations are bundled Boron macros over small
runtime helpers. `.get` registers real Sinatra routes and `.create_table` passes
the schema callback to ActiveRecord, using `&` before the final block expression.
Route callbacks return `[status, headers, [body]]`, as supported by Sinatra/Rack.
JSON generation and queries are the real Ruby gems, not Boron implementations.

The app also uses the bundled `defn`, `when`, and `unless` convenience macros.
The same interop is possible through Class.new, const_set, def/fn/if, and explicit
block sends; macros make the declarations more readable. Declarations currently
have no bodies. This example has read-only routes; request parameters, Ruby
instance context, explicit keywords, methods, and class bodies are later design
work. The table setup is a small single-process demo bootstrap, not a migration
system.

Checked October 1, 2026 against ActiveRecord 8.1.4, Sinatra 4.2.1, sqlite3 2.9.6,
and Puma 8.0.2 on Ruby 4.0.7. References:

- [Sinatra modular apps, routes, return values, and server setup](https://sinatrarb.com/intro.html)
- [ActiveRecord connection handling](https://api.rubyonrails.org/classes/ActiveRecord/ConnectionHandling.html)
- [ActiveRecord basics](https://guides.rubyonrails.org/active_record_basics.html)
- [sqlite3 Ruby gem](https://github.com/sparklemotion/sqlite3-ruby)
