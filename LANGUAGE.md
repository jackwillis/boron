# Boron: an informal language spec

Boron is a Lisp hosted on Ruby. The goal is a language with programmable forms,
lexical functions, and a direct relationship with Ruby's objects and libraries.
Ruby supplies the runtime; Boron supplies the language surface.

This document describes the bootstrap language as it works today. The last
section discusses the design we are heading toward. It is a working agreement,
not a compatibility standard: examples here should become tests as we refine it.

## A program is a sequence of forms

```clojure
(def greeting "hello")
(puts greeting)
(+ 1 (* 2 3))
```

Forms are read and evaluated in order. The last form is the program's result.
An empty program returns nil. Running a file does not print its result
implicitly; use `puts` or `print` when you want output.

Whitespace separates atoms. Commas are not separators. A semicolon starts a
comment that ends at the next newline or the end of the file.

Lists are parenthesized forms. In executable code, a nonempty list is a special
form or a callable invocation. `()` currently produces a compile error; it is
not an executable empty-list value.

## Values come from Ruby

| Boron source | Runtime value |
| --- | --- |
| `42`, `-12`, `+3` | Ruby Integer |
| `1.5`, `2e3`, `-2.5e-3` | Ruby Float |
| `"hello"` | Ruby String |
| `:name` | Ruby Symbol |
| `true`, `false`, `nil` | Ruby true, false, nil |
| `[1 2 3]` | Ruby Array |
| `{:name "Ada" :age 36}` | Ruby Hash |
| `#{:ruby :lisp}` | Ruby Set |

Collections evaluate their elements. A map can use any expression as its key:

```clojure
{(+ "first" "-name") (.upcase "ada")}
```

Maps contain alternating keys and values; an odd number of forms is an error.
Duplicate keys follow Ruby Hash behavior. Sets evaluate all elements, then remove
duplicates using Ruby Set behavior.

Collections are mutable. A vector literal is an actual Ruby Array, not a
persistent data structure disguised as one. Collection expressions allocate fresh
containers. String literals are frozen Ruby Strings, including literals inside
collections, quote/quasiquote, functions, and REPL submissions. Mutation of a
literal raises Ruby FrozenError. Use an explicit mutable copy when needed:

```clojure
(def name "Ada")
(def buffer (.dup name))
(.concat buffer "!") ; "Ada!"
```

String.new and Ruby library results retain their own mutability. Boron does not
freeze all String objects or deeply freeze collection contents. Explicit .dup
creates a fresh mutable copy on each evaluation. Frozen literal identity/reuse
is Ruby's behavior, not a promised Boron identity API. There is no per-file toggle.

Numbers currently use decimal syntax. A fractional part needs digits on both
sides of the decimal point. Non-finite float literals are rejected. Ruby handles
arithmetic, including integer division: `(/ 5 2)` returns `2`.

Strings support `\n`, `\r`, `\t`, `\"`, and `\\`. They can span lines. Unknown
escapes are errors. Interpolation is not implemented: `"#{name}"` is literal text.
Use Ruby methods or ordinary functions to assemble strings for now.

## Identifiers and literal symbols are different

```clojure
name  ; look up a Boron binding
:name ; return the Ruby Symbol :name
```

Identifiers can contain Lisp-friendly punctuation: `make-adder`, `active?`, and
`set!` are ordinary spellings. Bindings are case-sensitive. Numeric-looking tokens
that do not match the supported numeric grammar are currently identifiers.

A bare identifier does not invoke a zero-argument Ruby method. Missing bindings
raise `Boron::UnboundName` with the source filename, line, and column.

If an uppercase identifier has no Boron binding, it resolves as a Ruby constant.
Paths such as `Sinatra::Base` use explicit Ruby constant names. This is host
lookup, not a Boron namespace system.

## Definitions and local bindings

```clojure
(def x 10)

(let [x 2
      y (+ x 1)]
  (+ x y)) ; 5

x ; still 10
```

`def` evaluates its value, writes a session-global binding, and returns that value.
Definitions inside functions also write the session's globals. Redefinition is
allowed. Global lookup happens when a function runs, so recursive definitions work.

`let` introduces lexical bindings. Initializers run left to right: each sees
outer bindings and the bindings introduced before it. An initializer does not
see the new binding it is about to create. The body sees every let binding.

Earlier closures retain the earlier scope:

```clojure
(def x 10)
(let [f (fn [] x)
      x 20]
  (f)) ; 10
```

Duplicate names within one binding vector are rejected. Nested lets may shadow
names. A binding vector requires alternating identifiers and values; destructuring
is not available yet. Let bodies return their last expression, or nil if empty.

## Functions are values

```clojure
(def square
  (fn [x] (* x x)))

(square 8) ; 64
((fn [x] (* x x)) 5) ; 25
```

`fn` creates a Ruby lambda that captures its lexical environment. Functions
accept a parameter vector and zero or more body expressions. The last expression
is the result; an empty body returns nil. Arity is strict.

```clojure
(def make-adder
  (fn [x]
    (fn [y] (+ x y))))

(def add2 (make-adder 2))
(add2 5) ; 7
```

A final rest parameter follows `&`:

```clojure
((fn [first & remaining] remaining) 1 2 3) ; [2 3]
```

The rest value is a Ruby Array. Duplicate parameters and malformed rest parameter
lists are compile errors. Optional parameters and keyword parameters are deferred.

`(f x y)` evaluates the callee and arguments and invokes the callee's `call`
method. It never silently turns into a method send on `x`.

## Control flow uses Ruby truth

Only false and nil are falsey. Zero, empty strings, and empty collections are truthy.

```clojure
(if active?
  "yes"
  "no")
```

Only the chosen branch is evaluated. The else branch is optional and defaults
to nil. `if` requires a condition and a then expression.

```clojure
(do
  (puts "working")
  42)
```

`do` evaluates its forms in order and returns the last result, or nil if empty.

The current privileged forms are `def`, `let`, `fn`, `if`, `do`, and `set!`.
Their spellings are recognized in list-head position before ordinary calls.
A binding with the same name does not override that special-form interpretation;
a stronger policy for reserving these names is still open.

## Mutation is explicit

```clojure
(def counter
  (let [n 0]
    (fn []
      (set! n (+ n 1)))))

(counter) ; 1
(counter) ; 2
```

`set!` changes the nearest existing binding and returns the assigned value.
It cannot create a binding. Closures share the binding they captured, so mutation
is visible through every closure that holds it.

Ruby object mutation uses normal Ruby messages:

```clojure
(let [xs [1 2]]
  (.push xs 3)
  xs) ; [1 2 3]
```

## Ruby messages are a separate operation

```clojure
(.upcase "hello") ; "HELLO"
(.new String "hello")
(.[] [10 20] 1)    ; 20
(send "hello" :upcase)
```

The `.method` shorthand evaluates the receiver, then its arguments, and invokes
Ruby `public_send`. Operators, setters, and unusual method names can also be
sent through `(send receiver :method args...)`. Private methods are not exposed
through these sends. Classes and modules are ordinary Ruby objects.

There is no automatic name conversion: `(.display-name user)` sends Ruby's
`:"display-name"`, not `:display_name`.

```clojure
(require "json")
(.generate JSON {:hello "world"}) ; JSON string
```

`require` calls Ruby's actual require. RubyGems and Bundler remain the mechanisms
for installing and selecting host libraries. Boron does not wrap or replace them.

Hashes stay positional Hash arguments. There is no automatic conversion into
Ruby keyword arguments. Splat, double-splat, and keyword argument syntax remain
open design work.

## Named Ruby classes and modules

```clojure
(defmodule BoronDemo)
(defmodule BoronDemo::Models)
(defclass BoronDemo::Models::User < ActiveRecord::Base)
(defclass BoronDemo::Plain)
```

These are bundled macros that create named Ruby constants and return the actual
Module or Class. A new class defaults to Object as its superclass. After `<`, a
superclass expression is evaluated once and must return a Ruby Class. Names must
be unquoted uppercase identifiers or qualified constant paths. Declare parent
namespaces first; missing namespaces are not created implicitly.

Declarations affect Ruby's shared constant space, not a session's Boron bindings.
Existing modules/classes are reused. An explicit superclass must match an
existing class; a class declaration without `<` leaves its superclass unchanged.
A conflicting constant type raises TypeError rather than replacing the constant.
Constant lookup for ownership and reuse excludes inherited constants. These
rules allow safe repetition of matching declarations across sessions, though
Ruby's normal global state remains shared.

This slice accepts no declaration bodies. Methods, slots, nested-body name
resolution, and implicit self are deferred. `.const_set` remains available for
other Ruby constant operations.

## Blocks must be passed deliberately

A Ruby block is distinct from an ordinary Proc argument:

```clojure
(send-with-block [1 2 3] :map []
  (fn [x] (* x 2))) ; [2 4 6]
```

`send-with-block` takes a receiver, method, Array of positional arguments, and
Proc. It invokes the Ruby method with that Proc in its block position. In contrast,
`(.map xs f)` passes `f` as a positional argument; it does not invent a block.

This primitive also works with File.open and its host-managed resource cleanup.
Method sends accept `&` before one final block expression. Preceding arguments
are passed normally. This is compiler syntax, not a macro:

```clojure
(.map [1 2] & (fn [x] (* x 2)))
(.get BoronDemo::App "/health" & (fn [] "hello"))
```

The marker follows the receiver and any positional arguments. Ruby handles
block conversion: a Proc or an object with `to_proc` becomes a block, and nil
means no block. Receiver, positional arguments, and block expression evaluate
once in that order. Without `&`, Proc arguments stay positional arguments.
`send-with-block` remains useful for dynamically chosen method names. There is
no `send&` alias or special `.method&` suffix.

`&` is contextual syntax, not a globally reserved name. In a function parameter
vector it introduces rest arguments; directly among method-send arguments it
introduces the final block. At an ordinary call head it looks up a callable:

```clojure
(def & (fn [left right] (.& left right)))
(& #{1 2} #{2 3}) ; Ruby Set containing 2
```

There is no built-in `&` binding yet: define one before calling it. `def`, `let`,
and `set!` accept `&` as a binding name. `do` retains its existing sequence-form
meaning; a `do` block marker remains a proposal.

## Explicit Ruby instance context

`with-self` wraps a callable as a Ruby Proc that supplies the host's current Ruby
self as the first positional argument. The remaining host arguments follow it:

```clojure
(.instance_exec "Ada" & (with-self (fn [self] (.upcase self)))) ; "ADA"

(defclass Greeter)
(.define_method Greeter :greet &
  (with-self (fn [self name] (+ "Hello, " name))))
(.greet (.new Greeter) "Ada") ; "Hello, Ada"
```

Use it when the Ruby host rebinds self, such as instance_exec, define_method, or
Sinatra routes. It preserves lexical Boron captures and the wrapped function's
strict arity. Reusing a callback supplies the current instance on every call.
There is no implicit self binding in ordinary fn. The parameter may have any
name; `self` is a convention. Ordinary callbacks do not automatically receive
the method receiver: with-self exposes Ruby's block context, which is determined
by the host. This bridge forwards positional arguments only; keyword/block
forwarding is not a new language feature.

The optional Sinatra example uses `(fn [self & captures] ...)` because Sinatra
also passes route captures. It reads `(.params self)` and uses ActiveRecord's
find_by for `/users/:id`, returning a JSON 404 for invalid or missing IDs.

## The small builtin library

| Binding | Meaning |
| --- | --- |
| `+`, `*` | Left-to-right Ruby operations; zero arguments return 0 and 1 |
| `-` | Unary negation or left-to-right subtraction |
| `/` | Division with at least two arguments |
| `%` | Binary Ruby modulo |
| `=`, `==`, `!=`, `<`, `<=`, `>`, `>=` | Adjacent-pair Ruby comparisons, at least two operands |
| `not` | Ruby truth negation |
| `puts`, `print` | Ruby console output |
| `get` | Ruby indexing with collection and key |
| `map` | `(map f collection)` eagerly transforms each element into an Array |
| `filter` | `(filter predicate collection)` selects elements using Ruby truth |
| `reduce` | `(reduce f initial collection)` folds left from an explicit initial value |
| `group-by` | `(group-by f collection)` creates a Ruby Hash of key → element Arrays |
| `count` | Counts elements of a Ruby Enumerable |
| `require` | Ruby library loading |
| `send` | Explicit public Ruby dispatch |
| `send-with-block` | Public dispatch with a distinct Ruby block |
| `with-self` | Wrap a callable to receive the host Ruby self as its first argument |

These are callable bindings and can be shadowed. For example:

```clojure
(let [+ (fn [a b] 99)]
  (+ 1 2)) ; 99
```

Sequence helpers use Ruby's Enumerable operations. Callbacks receive one element
at a time; Hash elements are `[key value]` pairs. Reduce callbacks receive the
accumulator and the element. Helpers preserve host equality/order and do not
mutate the input themselves; callbacks can still mutate host objects. No lazy
sequence abstraction is introduced.

## Compilation and errors

The implementation reads syntax with source spans, lowers it to Ruby-oriented
IR, emits Ruby source, and lets Ruby compile and execute it. The runtime helper
is deliberately small: environments, callable builtins, and host integration.

Reader and compiler errors include original source locations. Binding errors
include the identifier's location. Ruby runtime exceptions retain their Ruby
classes. Runtime stack traces still point at generated Ruby lines; source maps
are future work. There are no Boron try/catch forms yet.

`boron run file.bn [-- PROGRAM_ARGS...]` executes a file. Only arguments after
the separator are exposed to that program as `ARGV`; the Ruby process's own ARGV
is not mutated. Emitted Ruby uses normal Ruby ARGV.
`boron compile file.bn` emits Ruby requiring
the Boron runtime. `compile --emit-ruby` is an equivalent inspection command.
Programs currently run through `./bin/boron` from the repository.

## Interactive use

`boron repl` runs a persistent Session. Enter forms across lines; parentheses,
collection delimiters, strings, and quotation prefixes are checked by the reader.
Incomplete submissions wait for more input. Completed submissions print their
last result; whitespace and comment-only input are ignored. Multiple forms in
one completed submission share normal compilation and phase-ordering rules.

`:help` prints help; `:quit` and `:exit` leave when no submission is in progress.
EOF exits normally, or reports incomplete buffered input with status 1. Ctrl+C
clears an unfinished submission or returns from interrupted evaluation. Prompts
appear only for terminal input; piped input emits results without prompts. Reader,
compile, and ordinary runtime errors are reported and the loop continues.
Definitions and macro definitions persist; evaluations are not transactions and
side effects before an error are not rolled back. SystemExit remains host exit.

The Printer renders forms and collections in readable Lisp notation, with cycle
and depth guards. Other host objects use inspect. This is display, not a guaranteed
read/write serialization format. There is no readline history or completion.

## Diagnostics

Reader and compile errors expose structured diagnostics and source spans. CLI and
REPL excerpts use snapshots; duplicate binding diagnostics label both occurrences.
Library exception classes and concise messages remain available. Runtime binding
errors carry their original locations; other Ruby exceptions remain native.
Runtime source maps, suggestions, error codes, and JSON output are future work.
See DIAGNOSTICS.md for the exact implemented boundary.

## Quotation and macros

Quotation and macros are implemented. `'x` is shorthand for `(quote x)`;
backtick constructs a quasiquoted form, `~x` inserts an evaluated value, and
`~@xs` splices a Form list/vector or Ruby Array into a surrounding collection.
Quoted identifiers are distinct from Ruby Symbols. Quoted lists, vectors, maps,
and sets are immutable Form datums rather than ordinary Ruby collections.

```clojure
(defmacro twice [expression]
  `(+ ~expression ~expression))
(defn square [x] (* x x))
(when true (puts (square (twice 3))))
(macroexpand '(when true (puts "hello")))
```

`defmacro` is top-level syntax with the same strict/rest parameter rules as fn.
Definitions take effect in source order and persist in a Session. Macro bodies
run in an isolated compile-time environment, so runtime def bindings are not
available. Macro arguments are unevaluated Form datums; macro results must be
form datums, not runtime Arrays/Hashes. `list`, `vector`, `first`, `rest`, `cons`,
`concat`, `apply`, and `list?` support form manipulation. `rest` and `concat`
return Arrays; use list/vector to construct code.

`defn`, `when`, and `unless` are ordinary bundled macros. Use `(gensym)` or
`(gensym "prefix")` for introduced bindings to avoid accidental capture.
Macros are not automatically hygienic. `(macroexpand 'form)` returns a fully
expanded form datum without executing it. Expansion failures report the call
site; reused structural arguments retain their own source locations.

Later, class bodies and method syntax should extend the small runtime API behind
`defclass` and `defmodule`. Sequence helpers, threading
macros and destructuring remain future conveniences; the REPL is implemented.
Protocols may eventually add abstraction over existing Ruby classes without
monkey-patching them.

Boron is not aiming for Scheme, Clojure, or Common Lisp compatibility. Proper
tail calls, continuations, mandatory persistent collections, and a new VM are
not bootstrap requirements. The useful boundary is explicit: Boron owns syntax
and lexical meaning; Ruby owns the runtime objects and the ecosystem.

Boron-first testing forms, project scaffolding, bundle-aware commands, and task DSL
syntax are planned and are not part of the current language/library API. Existing
examples select optional dependencies through ordinary Gemfiles and Bundler.
