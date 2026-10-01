# Boron

[![Tests](https://github.com/jackwillis/boron/actions/workflows/ci-cd.yml/badge.svg?branch=main)](https://github.com/jackwillis/boron/actions/workflows/ci-cd.yml)

Boron is a Lisp hosted on Ruby. Ruby provides runtime values and libraries;
Boron provides S-expressions, lexical functions, and compile-time macros.

This is an experimental bootstrap compiler written in Ruby. It reads Boron forms,
lowers them to a small Ruby IR, emits Ruby source, and executes through Ruby.

```clojure
(require "json")

(def greet
  (fn [name] (.generate JSON {:message name :active true})))

(puts (greet "Hello from Boron!"))
; {"message":"Hello from Boron!","active":true}
```

Boron collections are Ruby collections, and `.method` calls Ruby methods directly.
The goal is Lisp syntax and macros with access to existing Ruby libraries. This is
an early language implementation; see [Language core](#language-core) for what
works today and [ROADMAP.md](ROADMAP.md) for what comes next.

## Quick start

Use Ruby 3.3 or newer (currently verified on Ruby 4.0.7). No external runtime gems
are required for Boron itself. Required host libraries still need to be installed.

Clone the repository and run an example directly; Bundler is only needed for
development or examples with extra dependencies.

```sh
git clone https://github.com/jackwillis/boron.git
cd boron
./bin/boron run examples/hello.bn
./bin/boron run examples/make_adder.bn
./bin/boron run examples/json.bn
./bin/boron run examples/blocks.bn
./bin/boron run examples/user_report.bn -- examples/users.json
./bin/boron compile --emit-ruby examples/make_adder.bn
```

The hello example prints `Hello from Boron!` and `7`.

`run` executes the program; use `puts` or `print` for output. `compile` writes Ruby
to stdout without executing the program. Emitted Ruby requires Boron's runtime:

```sh
./bin/boron compile examples/make_adder.bn > /tmp/make_adder.rb
ruby -Ilib /tmp/make_adder.rb
```

Pass program arguments after `--`; the program sees only those arguments in
`ARGV`. Compiled Ruby receives normal Ruby command-line arguments.

## Examples

| Example | What it demonstrates |
| --- | --- |
| [hello.bn](examples/hello.bn) | Output and arithmetic |
| [make_adder.bn](examples/make_adder.bn) | Functions and lexical closures |
| [json.bn](examples/json.bn) | Ruby's JSON library |
| [blocks.bn](examples/blocks.bn) | Passing blocks to Ruby methods |
| [user_report.bn](examples/user_report.bn) | Filtering and grouping JSON records; pass `examples/users.json` after `--` |
| [SQLite web app](examples/sqlite_web/README.md) | ActiveRecord, SQLite, and Sinatra, with a separate gem bundle |

## Language core

```clojure
(def make-adder
  (fn [x]
    (fn [y] (+ x y))))

(def add2 (make-adder 2))
(puts (add2 5)) ; 7

(let [x 2 y (+ x 1)]
  (+ x y)) ; 5

(require "json")
(.generate JSON {:name "Ada" :active true})

(send-with-block [1 2 3] :map []
  (fn [x] (* x 2))) ; [2 4 6]
```

Implemented syntax:

- Lists, vectors, maps, sets, strings, decimal numbers, Ruby symbol literals,
  booleans, nil, and `;` comments.
- `def`, sequential `let`, `fn` (including `&` rest parameters), `if`, `do`, `set!`.
- First-class callable values, lexical closures, global recursion, Ruby truth.
- Explicit `.method` sends, including `.[]`, and uppercase Ruby constant paths.

Builtins: `+`, `-`, `*`, `/`, `%`, `=`, `==`, `!=`, `<`, `<=`, `>`, `>=`,
`not`, `puts`, `print`, `get`, `map`, `filter`, `reduce`, `group-by`, `count`,
`require`, `send`, `send-with-block`.
Operators are ordinary bindings and can be shadowed. Collections are actual Ruby
Arrays, Hashes, and Sets. Ruby exceptions propagate through the Ruby API.

Strings support `\n`, `\r`, `\t`, `\"`, and `\\`; they do not interpolate Ruby
or Boron expressions. Functions return their last expression. False and nil are
falsey; everything else is truthy. A Proc argument remains an argument unless
passed through `send-with-block` or marked with `&` in a method send.
In ordinary calls, `&` can name a user-defined callable; it has no builtin binding.

Quotation, quasiquotation, defmacro, macroexpand, gensym, and the core macros
`defn`, `when`, and `unless` are implemented. Named `defclass` and `defmodule`
declarations are implemented. Class bodies/methods, keyword/splat arguments,
destructuring, and a REPL remain future work. Runtime backtraces
currently refer to generated Ruby lines; source map work remains ahead.

## Documentation

- [LANGUAGE.md](LANGUAGE.md): implemented syntax and semantics.
- [DESIGN.md](DESIGN.md): current implementation decisions.
- [ROADMAP.md](ROADMAP.md): milestones, limitations, and planned work.
- [SPEC.md](SPEC.md): original proposal, including aspirational syntax that is not implemented.
- [TESTING.md](TESTING.md): test audit, optional integration checks, and coverage limits.
- [DIAGNOSTICS.md](DIAGNOSTICS.md): diagnostic design and acceptance criteria.
- [VS Code support](editors/vscode/README.md): local extension loading and tokenizer tests.

## Development

```sh
bundle config set --local path vendor/bundle
bundle install
bundle exec standardrb
bundle exec ruby -Itest test/all_test.rb
```

Development uses Minitest 5 for tests and StandardRB (`standard`) for linting and
formatting. Tests cover reader and compiler semantics, Ruby emission, and CLI
subprocesses. Work proceeds through failing tests, implementation, and refactoring.
Use `bundle exec standardrb --fix` to apply the agreed Ruby style.
See [TESTING.md](TESTING.md) for the recent test audit and remaining coverage limits.

VS Code highlighting and editing support lives in [editors/vscode](editors/vscode/README.md).
It has no npm dependencies or build step; its README explains local loading and
tokenizer tests.

## Ruby API

```ruby
require_relative "lib/boron"

forms = Boron::Reader.new("(+ 1 2)", filename: "example.bn").read_all
ruby = Boron::Compiler.new.compile("(+ 1 2)", filename: "example.bn")

session = Boron::Session.new
session.evaluate("(def x 10)")
session.evaluate("(+ x 2)") # => 12
```

Each parsed form is a syntax object with a datum and source span. Compiler IR is
available through `Compiler#lower`. Sessions retain their own environments across
evaluations; independent sessions have separate Boron globals. Host Ruby libraries
and their global state are shared normally.

## Build a gem

```sh
gem build boron.gemspec
gem install --local boron-0.1.0.gem
boron run examples/make_adder.bn
```

The gem packages the runtime, `bin/boron`, examples, and language documentation.
Its version is defined in `lib/boron/version.rb`. Development tools and editor
files are not included, and the gem has no external runtime dependencies.
Boron is available under the [MIT license](LICENSE).

## Continuous integration

The [GitHub Actions workflow](https://github.com/jackwillis/boron/actions/workflows/ci-cd.yml)
runs StandardRB followed by Minitest on Ruby 3.3, 3.4, and 4.0 for pushes,
pull requests, and manual runs. Separate jobs run the SQLite web integration
tests on Ruby 4.0 and the editor tokenizer tests with stable VS Code. After all
checks pass, it builds the gem on Ruby 4.0. The badge above reports the overall
workflow status on `main`, including lint, tests, and the gem build. Local
instructions for the web integration and editor tokenizer tests are in
[TESTING.md](TESTING.md).

The workflow checks that the gem builds; it does not upload artifacts or publish
releases. To try Boron today, use the checkout or build the gem locally.
