# Boron

Boron is a Lisp hosted on Ruby. Ruby provides runtime values and libraries;
Boron provides S-expressions and lexical functions. Macros are the next milestone.

This is an experimental bootstrap compiler written in Ruby. It reads Boron forms,
lowers them to a small Ruby IR, emits Ruby source, and executes through Ruby.

## Try it

Use Ruby 3.2 or newer (currently verified on Ruby 4.0.7). No external runtime gems
are required for Boron itself. Required host libraries still need to be installed.

```sh
./exe/boron run examples/hello.bn
./exe/boron run examples/make_adder.bn
./exe/boron run examples/json.bn
./exe/boron run examples/blocks.bn
./exe/boron compile --emit-ruby examples/make_adder.bn
```

`run` executes the program; use `puts` or `print` for output. `compile` writes Ruby
to stdout without executing the program. Emitted Ruby requires Boron's runtime:

```sh
./exe/boron compile examples/make_adder.bn > /tmp/make_adder.rb
ruby -Ilib /tmp/make_adder.rb
```

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
