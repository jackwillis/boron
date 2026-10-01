# Boron

Boron is a Lisp hosted on Ruby. Ruby provides runtime values and libraries;
Boron provides S-expressions and lexical functions. Macros are the next milestone.

This is an experimental bootstrap compiler written in Ruby. It reads Boron forms,
lowers them to a small Ruby IR, emits Ruby source, and executes through Ruby.

## Try it

Use Ruby 3.2 or newer (currently verified on Ruby 4.0.7). No external runtime gems
are required for Boron itself. Required host libraries still need to be installed.

```sh
./bin/boron run examples/hello.bn
./bin/boron run examples/make_adder.bn
./bin/boron run examples/json.bn
./bin/boron run examples/blocks.bn
./bin/boron compile --emit-ruby examples/make_adder.bn
```

`run` executes the program; use `puts` or `print` for output. `compile` writes Ruby
to stdout without executing the program. Emitted Ruby requires Boron's runtime:

```sh
./bin/boron compile examples/make_adder.bn > /tmp/make_adder.rb
ruby -Ilib /tmp/make_adder.rb
```

## Build a gem

```sh
gem build boron.gemspec
gem install --local boron-0.1.0.gem
boron run examples/make_adder.bn
```

The gem packages the runtime, `bin/boron`, examples, and language documentation.
Its version is defined in `lib/boron/version.rb`. Development tools and editor
files are not included, and the gem has no external runtime dependencies.
License and homepage metadata are still undecided.

## CI and CD

The GitHub Actions workflow in `.github/workflows/ci-cd.yml` runs on pushes,
pull requests, and manual dispatch. CI installs development/test dependencies,
runs StandardRB, then runs Minitest on Ruby 3.3, 3.4, and 4.0. Once the entire
matrix succeeds, CD builds the gem on Ruby 4.0 with `gem build`.
There is no artifact upload or publishing step; the build remains on the runner.

Workflow setup follows the current [GitHub Actions syntax reference](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax)
and [ruby/setup-ruby guidance](https://github.com/ruby/setup-ruby).
The matrix covers [currently maintained Ruby branches](https://www.ruby-lang.org/en/downloads/branches/),
including [Debian 13's packaged Ruby 3.3](https://packages.debian.org/trixie/ruby).
It tests the Ruby versions on Ubuntu runners, not Debian's packages themselves.
Debian 12's Ruby 3.1 is below Boron's Ruby 3.2 minimum.

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
`not`, `puts`, `print`, `get`, `require`, `send`, `send-with-block`.
Operators are ordinary bindings and can be shadowed. Collections are actual Ruby
Arrays, Hashes, and Sets. Ruby exceptions propagate through the Ruby API.

Strings support `\n`, `\r`, `\t`, `\"`, and `\\`; they do not interpolate Ruby
or Boron expressions. Functions return their last expression. False and nil are
falsey; everything else is truthy. A Proc argument remains an argument unless
passed through `send-with-block`.

Quotation, macros, class primitives, keyword/splat argument syntax, destructuring,
and a REPL are not implemented. Runtime backtraces currently refer to generated
Ruby lines; source map work remains ahead.

## Development

```sh
bundle config set --local path vendor/bundle
bundle install
bundle exec ruby -Itest test/all_test.rb
bundle exec standardrb
```

Development uses Minitest 5 for tests and StandardRB (`standard`) for linting and
formatting. Tests cover reader and compiler semantics, Ruby emission, and CLI
subprocesses. Work proceeds through failing tests, implementation, and refactoring.
Use `bundle exec standardrb --fix` to apply the agreed Ruby style.

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

See [the informal language spec](LANGUAGE.md), [the original proposal](SPEC.md), [current decisions](DESIGN.md), and
[the milestone backlog](ROADMAP.md). The proposal includes tentative syntax and
aspirational examples; it is not a statement of implemented features.
