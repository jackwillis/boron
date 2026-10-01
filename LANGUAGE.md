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
persistent data structure disguised as one. Strings are also mutable, and
literal evaluation creates fresh strings and collections.

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
A friendlier block syntax can later be a macro over this operation.

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
| `require` | Ruby library loading |
| `send` | Explicit public Ruby dispatch |
| `send-with-block` | Public dispatch with a distinct Ruby block |

These are callable bindings and can be shadowed. For example:

```clojure
(let [+ (fn [a b] 99)]
  (+ 1 2)) ; 99
```

## Compilation and errors

The implementation reads syntax with source spans, lowers it to Ruby-oriented
IR, emits Ruby source, and lets Ruby compile and execute it. The runtime helper
is deliberately small: environments, callable builtins, and host integration.

Reader and compiler errors include original source locations. Binding errors
include the identifier's location. Ruby runtime exceptions retain their Ruby
classes. Runtime stack traces still point at generated Ruby lines; source maps
are future work. There are no Boron try/catch forms yet.

`boron run file.bn` executes a file. `boron compile file.bn` emits Ruby requiring
the Boron runtime. `compile --emit-ruby` is an equivalent inspection command.
Programs currently run through `./exe/boron` from the repository.

## Where this language is heading

Macros are the next language milestone. They should receive forms, return forms,
and expand before Ruby lowering. Quote, quasiquote, unquote, splice, gensym,
`defmacro`, and inspectable expansion belong together in that design pass.

The intended future feel includes:

```clojure
; Planned syntax, not implemented today.
(defmacro when [condition & body]
  `(if ~condition
     (do ~@body)
     nil))
```

Later, class syntax should construct real Ruby classes through a small primitive
API, with macros providing the convenient surface. Sequence helpers, threading
macros, destructuring, and a REPL should make Boron comfortable for everyday work.
Protocols may eventually add abstraction over existing Ruby classes without
monkey-patching them.

Boron is not aiming for Scheme, Clojure, or Common Lisp compatibility. Proper
tail calls, continuations, mandatory persistent collections, and a new VM are
not bootstrap requirements. The useful boundary is explicit: Boron owns syntax
and lexical meaning; Ruby owns the runtime objects and the ecosystem.
