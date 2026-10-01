# Boron

**Boron is a Lisp hosted on Ruby.**

It uses Ruby as its runtime substrate while providing a genuinely Lisp-oriented language: S-expression syntax, lexical functions, macros, explicit message sending, functional composition, and a programmable language surface.

Boron is not Scheme implemented in Ruby.

Boron is not Ruby with parentheses.

Boron is not initially an attempt to implement a new virtual machine.

The central question is:

> **What would a modern Lisp designed specifically for the Ruby runtime and Ruby ecosystem look like?**

Ruby provides the world.

Lisp provides the language.

---

# 1. Project goals

Boron should eventually feel roughly analogous to what Clojure is to the JVM:

- a distinct language
- hosted on an existing mature runtime
- designed around Lisp ideas
- able to use the host ecosystem directly
- opinionated about composition and abstraction
- capable of writing real applications

The analogy should not be taken literally.

Boron does not need to copy Clojure.

It should learn from:

- Clojure
- Common Lisp
- Scheme
- Ruby
- Hy
- Racket

while developing a language appropriate to Ruby specifically.

The highest-level priorities are:

1. **Be a real Lisp.**
2. **Interop with Ruby should be nearly frictionless.**
3. **Use Ruby values and Ruby runtime semantics where practical.**
4. **Keep the privileged semantic core small.**
5. **Make macros powerful and inspectable.**
6. **Distinguish lexical function calls from Ruby method dispatch.**
7. **Treat Ruby classes as runtime objects rather than parser-level sacred syntax.**
8. **Make functional programming natural without denying Ruby's mutable runtime.**
9. **Compile through Ruby first.**
10. **Optimize for usefulness and coherent design rather than standards compatibility.**

---

# 2. Boron is not Luxury Scheme

There is another project, Luxury Scheme, whose purpose is pedagogical and specification-oriented.

Luxury asks:

> How does Scheme work?

Boron asks:

> What should a Lisp for the Ruby world be?

Those goals should remain separate.

Luxury may deliberately implement difficult language semantics because learning them is the point.

Boron should shamelessly reuse Ruby's runtime whenever doing so gives us a better language faster.

Boron should not inherit Scheme requirements merely because Scheme is a Lisp.

In particular, Boron does **not** initially need:

- R7RS compatibility
- Scheme pairs as the universal sequence representation
- Scheme's exact/inexact numeric system
- proper tail calls
- first-class continuations
- Scheme truth semantics
- Scheme's library system
- Scheme's equality predicates
- Scheme compatibility generally

Boron is allowed to be its own language.

---

# 3. Ruby is the runtime substrate

Boron should use real Ruby runtime objects whenever possible.

The tentative value mapping is:

```text
Boron                 Ruby

integer               Integer
float                 Float
string                String
symbol literal        Symbol
vector                Array
map                   Hash
set                    Set
regexp                 Regexp
exception              Exception
class                  Class
module                 Module
object                 Object
callable host value    Proc or compatible callable
```

This is important.

Ruby interop should not require constant conversion between Boron collections and Ruby collections.

Passing this:

```clojure
{:name "Ada"
 :active true}
```

to Ruby should ideally mean passing an actual Ruby Hash.

Passing:

```clojure
[1 2 3]
```

should mean passing an actual Ruby Array.

This sacrifices some purely functional properties in exchange for dramatically better host integration.

That is currently the preferred tradeoff.

Persistent data structures may be added later as explicit Boron library types.

---

# 4. Lisp owns the syntax

Although Ruby owns the runtime values, Ruby does not own Boron's syntax or binding semantics.

Boron source should be made primarily from forms.

Example:

```clojure
(def greeting "hello")

(def greet
  (fn [name]
    (puts "#{greeting}, #{name}")))
```

Boron should have:

- symbols
- lists/forms
- vectors
- maps
- sets
- strings
- numbers
- booleans
- nil
- quote
- quasiquote
- unquote
- splice/unquote-splicing

Code should have an ordinary data representation accessible to macros.

---

# 5. Lexical bindings and Ruby messages are different things

This distinction should be fundamental.

Ruby has historical ambiguity between local-variable lookup and zero-argument method invocation.

Boron should not reproduce that ambiguity.

A bare symbol refers to a lexical or global Boron binding:

```clojure
user
```

A Ruby message send should be explicit:

```clojure
(.name user)
```

Conceptually:

```text
foo
```

means:

```text
resolve the Boron binding named foo
```

while:

```clojure
(.foo object)
```

means:

```text
send the Ruby message :foo to object
```

Arguments follow:

```clojure
(.map users f)
```

Conceptually:

```ruby
users.map(f)
```

This separation is one of Boron's most important semantic design choices.

---

# 6. Function calls are not method sends

Likewise:

```clojure
(f x y)
```

means calling the Boron value bound to `f`.

It does **not** implicitly mean:

```ruby
x.f(y)
```

A Boron callable should likely lower initially to a Ruby Proc or another callable runtime representation.

Method dispatch remains explicit:

```clojure
(.foo receiver x y)
```

This gives Boron two clean forms of invocation:

```text
(f x y)                 lexical callable invocation

(.method receiver x y)  Ruby dynamic dispatch
```

This distinction should remain visible even if syntax sugar is later added.

---

# 7. Operators

Boron may make arithmetic look traditionally Lispy:

```clojure
(+ 1 (* 2 3))
```

Semantically these operations should normally use Ruby behavior.

Possible lowering:

```ruby
1 + (2 * 3)
```

or conceptually:

```ruby
1.public_send(:+, 2.public_send(:*, 3))
```

The former is preferable when normal Ruby syntax gives the Ruby compiler better optimization opportunities.

The language-level meaning is still Ruby method semantics unless Boron explicitly defines otherwise.

Therefore:

```clojure
(+ x y)
```

should respect whatever Ruby's `+` means for those runtime values.

This keeps Ruby classes extensible and avoids building a competing numeric/object dispatch system.

---

# 8. Core special forms

Keep the privileged core small.

An initial semantic core might contain only forms equivalent to:

```text
quote
if
do
def
let
fn
set!
send
try
throw
```

Possibly also low-level forms for:

```text
class creation
method definition
constant lookup
Ruby require/load
```

Everything else should be a candidate for implementation as:

- macros
- ordinary Boron functions
- Ruby interop
- standard library code

Do not prematurely bake convenient syntax into the compiler.

---

# 9. Definitions

Basic definition:

```clojure
(def x 10)
```

Function definition may initially simply be sugar:

```clojure
(def square
  (fn [x]
    (* x x)))
```

A `defn` macro can expand to that:

```clojure
(defn square [x]
  (* x x))
```

This is preferable to implementing `defn` as a primitive compiler feature.

---

# 10. Lexical bindings

Preferred syntax:

```clojure
(let [x 10
      y 20]
  (+ x y))
```

Bindings should be lexical.

Shadowing should work predictably.

Initial language semantics should not inherit Ruby's local-variable parsing rules.

---

# 11. Functions

Anonymous function:

```clojure
(fn [x]
  (* x x))
```

Multiple expressions:

```clojure
(fn [x]
  (puts x)
  (* x x))
```

The last expression should be the result.

Functions should be ordinary values.

They should support closures:

```clojure
(def make-adder
  (fn [x]
    (fn [y]
      (+ x y))))
```

The initial implementation can map these naturally onto Ruby closures.

---

# 12. Truth

Unless compelling evidence suggests otherwise, Boron should initially use Ruby truth semantics:

```text
false and nil are falsey
everything else is truthy
```

This is an important example of choosing Ruby value semantics instead of Scheme tradition.

---

# 13. Collections

Initial literal syntax:

```clojure
[1 2 3]

{:name "Ada"
 :age 36}

#{:ruby :lisp :macros}
```

Tentative runtime mapping:

```text
vector -> Array
map    -> Hash
set    -> Set
```

Map syntax should support arbitrary expressions as keys eventually.

Keyword-looking syntax should probably produce Ruby Symbols:

```clojure
:name
```

→

```ruby
:name
```

This provides an extremely useful natural mapping between Lisp keyword idioms and Ruby's Symbol-heavy APIs.

---

# 14. Collection access

Avoid forcing users to write:

```clojure
(.[] params :id)
```

all the time.

The low-level method-send form should permit it:

```clojure
(.[] params :id)
```

but Boron should probably provide an idiomatic function:

```clojure
(get params :id)
```

Likewise:

```clojure
(get users 0)
```

This can simply call appropriate Ruby operations.

Do not introduce exotic indexing reader syntax in the first implementation.

Keep the reader simple initially.

---

# 15. Threading and functional composition

Boron should be excellent at data transformation.

Eventually support Clojure-inspired threading forms:

```clojure
(-> user
    (.profile)
    (.display-name))
```

and:

```clojure
(->> users
     (filter active?)
     (map name)
     sort)
```

These should be macros.

Sequence processing should become one of Boron's strongest library areas.

Likely important functions:

```text
map
filter
reduce
each
some
every?
find
group-by
partition
take
drop
first
rest
sort
concat
into
```

Where possible these should work naturally with Ruby's Enumerable ecosystem.

---

# 16. Ruby interop

Interop is not an auxiliary feature.

It is central to Boron.

The following should eventually feel easy:

## Constants

```clojure
Sinatra::Base
JSON
File
ActiveRecord::Base
```

The reader/parser needs an intentional representation for Ruby constant paths.

This may initially simply recognize symbols containing `::`.

## Static/class methods

Possible syntax:

```clojure
(.parse JSON source)
```

meaning conceptually:

```ruby
JSON.parse(source)
```

Because Ruby classes are objects, this requires no separate static-call abstraction.

## Constructors

Either:

```clojure
(.new User {:name "Ada"})
```

or convenience syntax:

```clojure
(new User {:name "Ada"})
```

`new` should probably be a function/macro over message sending rather than a new runtime concept.

## Instance methods

```clojure
(.upcase "hello")
```

## Mutation

```clojure
(.push xs value)
```

should mutate exactly as Ruby does.

Boron must not pretend Ruby mutation isn't happening.

---

# 17. Ruby blocks

Blocks need thoughtful treatment.

Ruby blocks are not identical to ordinary function arguments, and Ruby APIs frequently distinguish them.

Initial explicit syntax could be:

```clojure
(.each xs
  (block [x]
    (puts x)))
```

But that is somewhat noisy.

A preferable eventual design may permit a trailing Boron function to occupy Ruby's block position:

```clojure
(.each xs
  (fn [x]
    (puts x)))
```

This design requires care because some Ruby methods accept both ordinary Proc arguments and blocks.

Therefore:

**Priority:** support Ruby block semantics explicitly and correctly before optimizing syntax.

Possible primitive representation:

```clojure
(send-with-block receiver :each []
  (fn [x] ...))
```

with prettier syntax implemented over it.

Do not blur Ruby arguments and blocks accidentally.

---

# 18. Classes

Classes are one of Boron's defining design areas.

Boron should use real Ruby classes.

But Boron class syntax should feel like Lisp.

Tentative surface syntax:

```clojure
(defclass Person
  (slot name)
  (slot age)

  (method greet []
    (puts "Hello"))

  (method older-than? [n]
    (> age n)))
```

Inheritance:

```clojure
(defclass User < Person
  ...)
```

However, this surface should ideally be built over a much smaller runtime/core mechanism.

Conceptually:

```clojure
(make-class superclass)
```

returns a Ruby Class.

Method installation:

```clojure
(define-method! klass :greet
  (fn [self]
    ...))
```

Then `defclass` can eventually be mostly a macro.

This is important.

Boron should not make its entire class system into complicated privileged parser syntax.

---

# 19. Classes should be expressions

Because Ruby classes are objects, Boron should exploit that.

Anonymous class:

```clojure
(class Object
  (method greet []
    "hello"))
```

Binding it:

```clojure
(def Greeter
  (class Object
    (method greet []
      "hello")))
```

This is preferable philosophically to requiring every class to be a declaration.

`defclass` can just combine `def` and `class`.

---

# 20. Instance state

This area should be designed carefully rather than blindly copying Ruby syntax.

Possible early approach:

```clojure
(ivar-get self :name)
(ivar-set! self :name value)
```

Then nicer constructs:

```clojure
(slot name)
```

may expand into methods or lower-level slot operations.

Avoid introducing reader syntax such as `@foo` until the semantic design is clear.

The first implementation should prefer explicit internal forms over cute syntax.

---

# 21. Methods

Methods are different from Boron functions because they participate in Ruby dynamic dispatch.

Surface:

```clojure
(method greet [name]
  ...)
```

Inside a method, decide explicitly whether `self` is implicitly available.

Preferred initial direction:

`self` should be an ordinary explicit binding available in method bodies.

For example:

```clojure
(method greet []
  (.puts self "hello"))
```

Though convenient self-send syntax can be explored later.

Do not recreate Ruby's implicit receiver ambiguity until there is a good reason.

---

# 22. Protocols

Protocols should be a high-priority **post-MVP** language feature.

Ruby inheritance should not be Boron's only abstraction mechanism.

Possible syntax:

```clojure
(defprotocol Renderable
  (render [x]))
```

Implementations:

```clojure
(extend-protocol Renderable

  String
  (render [x]
    x)

  User
  (render [x]
    (.name x)))
```

This would provide open polymorphism over existing Ruby classes without monkey-patching them.

Exactly how protocol dispatch is implemented can wait.

Possible approaches include:

- registry keyed by Ruby class
- generated Ruby modules
- cached dispatch tables
- Ruby singleton/class metadata

Do not implement this until the language core is stable.

---

# 23. Multimethods

Multimethods are interesting but lower priority than protocols.

Possible eventual syntax:

```clojure
(defmulti collide
  (fn [a b]
    [(.class a) (.class b)]))
```

Then implementations:

```clojure
(defmethod collide [Asteroid Ship] [a b]
  ...)
```

This would distinguish Boron further from ordinary Ruby OO.

Again: not MVP.

---

# 24. Macros

Macros are essential.

A Boron without macros is merely an alternate Ruby syntax.

Macro system requirements:

- macros consume Boron forms
- macros return Boron forms
- expansion occurs before Ruby lowering
- macro expansion should be inspectable
- macros should support quasiquotation
- macro expansion errors should include useful source information

Example:

```clojure
(defmacro unless [condition & body]
  `(if (not ~condition)
     (do ~@body)))
```

Usage:

```clojure
(unless logged-in?
  (redirect "/login"))
```

Macro inspection:

```clojure
(macroexpand
  '(unless logged-in?
     (redirect "/login")))
```

should be supported relatively early.

---

# 25. Hygiene

Do not attempt sophisticated hygienic macro systems in the first version unless they fall out naturally.

A simple Common-Lisp-style macro system with generated unique symbols may be enough initially.

Provide something like:

```clojure
(gensym)
```

Later, reconsider hygiene based on actual pain.

The priority is making macros usable and understandable.

---

# 26. Reader

The reader should initially support:

```text
(...)
[...]
{...}
#{...}

symbols
keywords/symbol literals
integers
floats
strings
true
false
nil

'
`
~
~@
```

Comments:

```clojure
; comment
```

Do not overload the reader early.

Reader macros or extensible reader syntax are interesting future features but should not block the language core.

---

# 27. Syntax objects and source locations

Even if the first AST is simple, source location metadata should be planned for early.

Eventually errors and macro expansion need to retain:

- filename
- line
- column
- span

Avoid an AST architecture that makes source metadata painful to add.

A syntax-object layer may eventually distinguish:

```text
raw datum
syntax with source context
expanded form
```

But do not over-engineer before necessary.

---

# 28. Compilation strategy

Do **not** initially compile directly to YARV.

The first architecture should be:

```text
Boron source
    ↓
reader
    ↓
Boron forms / AST
    ↓
macro expansion
    ↓
semantic lowering
    ↓
Ruby-oriented IR
    ↓
Ruby source emitter
    ↓
Ruby compiler
    ↓
YARV
```

This lets Ruby handle:

- instruction selection
- VM compatibility
- call frames
- GC
- exception machinery
- optimization
- object layout
- runtime behavior

Boron should initially focus on language semantics.

---

# 29. Ruby IR

Do not scatter Ruby source string concatenation throughout the compiler.

Introduce a small Ruby-oriented intermediate representation.

Conceptually:

```text
RubyExpr
  Literal
  Local
  Call
  BlockCall
  Lambda
  Array
  Hash
  Constant
  If
  Begin
  Assign
  ClassExpr
  ...

RubyStmt
  Expr
  LocalAssign
  ConstantAssign
  MethodDef
  ...
```

The exact implementation language is undecided here; choose structures appropriate to the initial compiler implementation.

The important architectural principle is:

```text
Boron semantics
      ↓
Ruby IR
      ↓
Ruby source
```

not:

```text
every compiler function manually concatenates Ruby strings
```

Readable emitted Ruby is desirable.

---

# 30. Why emit Ruby source first?

Because generated Ruby is:

- easy to inspect
- easy to debug
- easy to run
- easy to compare with expected semantics
- already compilable to YARV
- compatible with normal Ruby tooling
- less brittle than directly constructing VM bytecode

Later, Boron may gain a direct YARV backend.

That should happen only when there is a concrete benefit.

Possible future pipeline:

```text
                   ┌─> Ruby source
Boron -> Ruby IR --|
                   └─> direct YARV
```

The Ruby-source backend should remain useful even after that.

---

# 31. Generated Ruby

Generated Ruby should be understandable whenever practical.

For example:

```clojure
(def square
  (fn [x]
    (* x x)))
```

could generate approximately:

```ruby
square = ->(x) { x * x }
```

rather than intentionally opaque runtime calls.

This is not mandatory when semantics require helpers, but readability is valuable for debugging and trust.

A compiler flag should eventually allow users to view generated Ruby:

```text
boron compile --emit-ruby app.bn
```

or equivalent.

---

# 32. Runtime support library

Some Boron operations will need runtime support.

Keep this runtime as small as practical.

Possible responsibilities:

- Boron callable helpers
- macro/runtime separation utilities
- namespace representation
- protocol dispatch
- Boron-specific error classes
- source metadata
- sequence helpers
- language version information

Avoid implementing Ruby functionality twice.

---

# 33. Namespaces

Namespace semantics should be designed explicitly.

Do not simply let Ruby constants become Boron's entire namespace system by accident.

Possible syntax:

```clojure
(ns my-app.web)
```

Definitions would belong to that Boron namespace.

Ruby constants should remain separately accessible.

Imports/requires may eventually resemble:

```clojure
(require "sinatra/base")

(require [my-app.models :as models])
```

But defer elaborate namespace syntax until basic evaluation works.

For MVP, a single top-level environment is acceptable.

---

# 34. Modules

Ruby modules remain useful runtime objects.

Eventually:

```clojure
(defmodule Greetings
  (method greet []
    ...))
```

could produce an actual Ruby Module.

Again, preferably as a macro/library abstraction over class/module runtime primitives.

---

# 35. Exceptions

Use Ruby exceptions.

Possible syntax:

```clojure
(try
  (dangerous-operation)

  (catch StandardError e
    (puts (.message e)))

  (finally
    (cleanup)))
```

Lower directly to Ruby exception constructs.

Do not invent a parallel exception model.

---

# 36. Mutation

Lexical bindings should lean toward functional usage, but Boron must support mutation because Ruby does.

Possible lexical mutation:

```clojure
(set! x 20)
```

Ruby object mutation remains ordinary message sending:

```clojure
(.push xs 4)
```

These are semantically different.

Keep the distinction clear.

---

# 37. Functional style

Boron should encourage:

```clojure
(def names
  (->> users
       (filter active?)
       (map display-name)
       sort))
```

without forbidding:

```clojure
(.push users new-user)
```

Functional programming is a default style, not a purity regime.

---

# 38. Sinatra should work

A medium-term demonstration target should be a real Sinatra app.

Desired eventual syntax:

```clojure
(require "sinatra/base")
(require "json")

(defclass App < Sinatra::Base

  (before
    (content-type :json))

  (get "/health"
    (json {:status "ok"}))

  (get "/users/:id"
    (let [user (User.find params[:id])]
      (json
        {:id (.id user)
         :name (.name user)}))))
```

The exact syntax will evolve.

The important goal is:

**Boron should use actual Sinatra, not a Boron reimplementation of Sinatra.**

Sinatra is a good integration test because it exercises:

- requiring gems
- constants
- subclassing
- DSL-style method calls
- blocks
- hashes
- strings
- dynamic dispatch
- web runtime behavior

---

# 39. Rails should eventually be plausible

Rails compatibility is not an MVP requirement.

But design decisions should avoid making it impossible.

Eventually something like:

```clojure
(defclass User < ApplicationRecord

  (belongs-to :account)

  (validates :email
    :presence true)

  (method display-name []
    (.upcase name)))
```

should be possible using actual Rails APIs.

Do not create a separate Boron Rails ORM or framework.

The Ruby ecosystem is the feature.

---

# 40. Standard library philosophy

Boron should have a modest standard library centered around things Lisp benefits from beyond Ruby's built-ins.

Potential focus:

- sequence functions
- predicates
- composition
- threading macros
- destructuring
- functional collection helpers
- macro utilities
- protocols
- multimethods
- namespace utilities

Do not duplicate Ruby's entire standard library.

Calling Ruby should remain normal.

---

# 41. Destructuring

Destructuring is a high-value post-core feature.

Example:

```clojure
(let [[x y] point]
  ...)
```

Map destructuring:

```clojure
(let [{:name name
       :age age} person]
  ...)
```

Clojure-inspired shorthand could come later.

Do not make complex destructuring part of the earliest parser/evaluator milestone.

---

# 42. Pattern matching

Ruby itself has pattern matching.

Boron may eventually expose pattern matching through Lisp forms.

This is not MVP.

When explored, determine whether Boron should:

- directly lower to Ruby pattern matching
- define its own pattern abstraction
- or both

Prefer leveraging Ruby unless Boron semantics require something different.

---

# 43. Concurrency

Boron should inherit Ruby concurrency capabilities initially.

Do not design an actor runtime, STM system, or green-thread scheduler during early language work.

Possible future libraries may provide:

- actors
- channels
- promises
- structured concurrency abstractions

But these are library concerns until proven otherwise.

---

# 44. Performance philosophy

Correct language semantics and usable interop come first.

Initial Boron will likely compile through Ruby source.

That is acceptable.

Optimization priorities should be driven by measurements later.

Possible future performance work:

- fewer runtime helper calls
- specialized lowering
- Ruby AST generation
- direct YARV bytecode
- inline caches
- protocol dispatch optimization
- static macro expansion caching
- compilation artifacts

No speculative optimizer in version 0.1.

---

# 45. Tooling philosophy

A Lisp lives or dies partly by its interactive experience.

Boron should eventually have:

```text
boron repl
boron run file.bn
boron compile file.bn
boron test
```

Potential extension:

```text
boron macroexpand
boron emit-ruby
```

The REPL should become a high priority shortly after the core evaluator/compiler runs.

---

# 46. File extension

Do not commit too strongly yet.

Candidates:

```text
.bn
.boron
.brn
```

`.bn` is compact but collision-prone.

`.boron` is explicit.

For early development, use `.bn` unless there is an obvious conflict.

This is easy to change before users exist.

---

# 47. Implementation language

Because Boron is hosted on Ruby, the first compiler should strongly consider being written in Ruby.

Reasons:

- direct access to Ruby runtime behavior
- simple bootstrapping
- easy execution of generated code
- easy gem integration
- easier experimentation with Ruby reflection
- lower conceptual distance from host semantics

A future Boron compiler may become partially self-hosted.

Do not make self-hosting an early goal.

Suggested bootstrap stages:

```text
Stage 0:
Ruby compiler/interpreter for Boron

Stage 1:
Boron can compile useful Boron programs

Stage 2:
Parts of Boron's standard library written in Boron

Stage 3:
Optional portions of compiler rewritten in Boron

Stage 4:
Possible self-hosting if genuinely valuable
```

---

# 48. Recommended initial implementation architecture

Suggested repository structure:

```text
boron/
├── README.md
├── MANIFESTO.md
├── DESIGN.md
├── ROADMAP.md
├── LICENSE
├── Gemfile
├── boron.gemspec
├── exe/
│   └── boron
├── lib/
│   ├── boron.rb
│   └── boron/
│       ├── version.rb
│       ├── token.rb
│       ├── lexer.rb
│       ├── reader.rb
│       ├── form.rb
│       ├── environment.rb
│       ├── expander.rb
│       ├── lower.rb
│       ├── ruby_ir.rb
│       ├── ruby_emitter.rb
│       ├── runtime.rb
│       └── cli.rb
├── test/
│   ├── lexer_test.rb
│   ├── reader_test.rb
│   ├── expander_test.rb
│   ├── lowering_test.rb
│   ├── emitter_test.rb
│   └── integration_test.rb
└── examples/
    └── hello.bn
```

Do not create every file merely because it appears here.

Start with the smallest coherent subset.

---

# 49. Testing

Use tests from the beginning.

Preferred test categories:

## Reader tests

Input:

```clojure
(+ 1 2)
```

Expected parsed representation.

## Expansion tests

Input:

```clojure
(when x y)
```

Expected expanded Boron form.

## Lowering tests

Input AST → expected Ruby IR.

## Emitter tests

Ruby IR → expected Ruby source.

## Integration tests

Boron program → execute → expected value/output.

Integration tests are especially important because the host runtime is part of the language semantics.

---

# 50. Source representation

Keep syntax representation simple early.

Possible Ruby classes:

```ruby
Boron::Form::Symbol
Boron::Form::List
Boron::Form::Vector
Boron::Form::Map
Boron::Form::Set
```

Primitive literals can remain ordinary Ruby values where unambiguous.

Be careful with Ruby Symbol versus Boron identifier.

For example:

```text
foo
```

is a Boron identifier.

```text
:foo
```

is a literal Ruby Symbol.

Those must be represented differently in the AST.

---

# 51. Reader milestone

The first meaningful milestone should be:

Input:

```clojure
(+ 1 (* 2 3))
```

Reader output resembling:

```ruby
List[
  Symbol("+"),
  1,
  List[
    Symbol("*"),
    2,
    3
  ]
]
```

No evaluation yet.

This milestone should include:

- whitespace
- lists
- vectors
- maps
- numbers
- strings
- identifiers
- symbol literals
- booleans
- nil
- comments

Quotation may come immediately after.

---

# 52. First compilation milestone

Compile:

```clojure
(+ 1 (* 2 3))
```

to approximately:

```ruby
1 + (2 * 3)
```

Then execute it through Ruby.

Expected result:

```text
7
```

This is Boron's first end-to-end milestone.

---

# 53. Second compilation milestone

Support:

```clojure
(let [x 2
      y 3]
  (+ x y))
```

Expected result:

```text
5
```

This establishes lexical bindings.

---

# 54. Third compilation milestone

Support:

```clojure
((fn [x]
   (* x x))
 5)
```

Expected:

```text
25
```

Then:

```clojure
(def square
  (fn [x]
    (* x x)))

(square 8)
```

Expected:

```text
64
```

This establishes closures and callable values.

---

# 55. Fourth milestone: Ruby messages

Support:

```clojure
(.upcase "hello")
```

Expected:

```text
"HELLO"
```

Then:

```clojure
(.map [1 2 3]
  (fn [x]
    (* x 2)))
```

This will expose the Ruby-block issue.

Handle it deliberately.

---

# 56. Fifth milestone: macros

Implement:

```text
quote
quasiquote
unquote
splice
defmacro
macroexpand
```

Then define something simple:

```clojure
(defmacro when [condition & body]
  `(if ~condition
     (do ~@body)
     nil))
```

This is the milestone where Boron becomes a Lisp rather than a Ruby expression compiler.

---

# 57. Sixth milestone: classes

Only after functions, macros, and Ruby sends work.

Implement low-level primitives first.

For example:

```clojure
(def Person
  (make-class Object))
```

Then:

```clojure
(define-method! Person :greet
  (fn [self]
    "hello"))
```

Then implement prettier class syntax as macros.

Do not begin with a huge class DSL.

---

# 58. Seventh milestone: real gem integration

Choose a small Ruby gem.

Sinatra is a good target.

Goal:

```clojure
(require "sinatra/base")
```

works.

Then instantiate/subclass/use actual Ruby library objects.

This validates Boron's reason for existing.

---

# 59. Priority roadmap

## P0 — prove the architecture

Implement:

- repository skeleton
- CLI capable of reading a file
- lexer/reader
- AST/forms
- Ruby IR
- Ruby emitter
- arithmetic
- literal values
- end-to-end execution

Target:

```clojure
(+ 1 (* 2 3))
```

works.

Do not add macros, classes, protocols, or advanced features yet.

---

## P1 — real lexical Lisp

Implement:

- symbols
- lexical environments
- `def`
- `let`
- `fn`
- function invocation
- `if`
- `do`
- closure capture
- booleans
- nil

Target:

```clojure
(def make-adder
  (fn [x]
    (fn [y]
      (+ x y))))

(def add2
  (make-adder 2))

(add2 5)
```

returns `7`.

---

## P2 — Ruby interop

Implement:

- explicit method sends
- constant lookup
- Ruby Symbol literals
- Arrays
- Hashes
- Sets if easy
- `require`
- constructors
- calling Ruby APIs
- Ruby exception propagation

Target:

```clojure
(require "json")

(JSON.generate
  {:hello "world"})
```

or equivalent explicit-message syntax works.

Do not invent wrapper APIs.

---

## P3 — macros

Implement:

- quote
- quasiquote
- unquote
- splice
- `defmacro`
- expansion pass
- recursive macro expansion
- `macroexpand`
- gensym

Target:

```clojure
(defmacro unless [condition & body]
  ...)
```

works.

At this point Boron is meaningfully a Lisp.

---

## P4 — Ruby blocks

Implement a correct explicit representation of Ruby blocks.

Then improve surface syntax.

Test against:

```text
Array#each
Array#map
File.open
Sinatra routes
```

Do not hack this by pretending blocks and arguments are identical.

---

## P5 — classes

Implement:

- creation of Ruby classes
- subclassing
- method definition
- instance variables/state
- constants
- modules if natural

Then build:

```text
class
defclass
method
slot
```

primarily through macros where possible.

---

## P6 — usable language ergonomics

Implement:

- `defn`
- `when`
- `unless`
- `when-let`
- threading macros
- common sequence functions
- destructuring
- better errors
- REPL
- generated-Ruby inspection

---

## P7 — ecosystem demonstration

Build real examples:

1. CLI program
2. JSON/data-processing script
3. Sinatra application
4. gem interop example
5. tests written in Boron

This stage should reveal whether the language feels genuinely useful.

---

## P8 — protocols

Implement Boron's first significant abstraction above Ruby OO.

Protocols should support existing Ruby classes without modifying them.

Then consider generic functions and multimethods.

---

## P9 — tooling and polish

Consider:

- source maps/source locations
- stack trace rewriting
- formatter
- editor syntax highlighting
- LSP
- package conventions
- compiled artifact caching
- gem packaging
- Boron libraries distributed through RubyGems

---

## P10 — direct YARV exploration

Only now investigate whether direct YARV emission provides enough benefit to justify complexity.

Treat it as an optional backend experiment.

Do not let it destabilize the language.

---

# 60. Non-goals for version 0.x

Explicitly avoid:

- Scheme compatibility
- Clojure compatibility
- Common Lisp compatibility
- implementing a VM
- implementing a garbage collector
- implementing a new object model
- replacing RubyGems
- replacing Bundler
- replacing Ruby's exception system
- replacing Ruby collections by default
- static typing
- direct YARV generation
- proper tail calls
- continuations
- persistent collections as mandatory defaults
- an elaborate module system
- production Rails support
- concurrency frameworks
- macro hygiene research projects
- optimization before profiling
- self-hosting for prestige

The project should remain small enough to move quickly.

---

# 61. Design heuristics

When uncertain, prefer these rules.

### Prefer Ruby runtime semantics over imitation

If Ruby already has a good runtime representation, use it.

### Prefer Lisp syntax over Ruby grammar

Do not inherit Ruby syntax quirks merely because Ruby is the host.

### Prefer explicit semantic distinctions

Function call and method send are different.

Lexical binding and object property are different.

Block and ordinary argument are different.

Make them distinguishable.

### Prefer macros over compiler privileges

If something can cleanly be a macro, strongly consider making it one.

### Prefer understandable lowering

Users should eventually be able to inspect what Boron becomes.

### Prefer real ecosystem compatibility

A Ruby gem working directly is better than a beautiful Boron wrapper around only 20% of the gem.

### Prefer usefulness over ideological purity

Ruby is mutable and object-oriented.

Boron should complement that environment, not wage war against it.

### Prefer experiments over premature doctrine

If two syntaxes are plausible, implement the smaller semantic core and try both later.

---

# 62. Questions intentionally left open

Do not resolve these prematurely unless implementation forces the issue.

- Should Boron have namespaces resembling Clojure?
- Should vectors always be mutable Ruby Arrays?
- Should Boron offer persistent collections later?
- How should block syntax work?
- Should `self` be implicit in methods?
- Should methods have shorthand self-send syntax?
- Should Ruby constants use ordinary `Foo::Bar` reader syntax?
- How should keyword arguments be represented?
- Should keyword maps automatically lower to Ruby kwargs?
- How should splat and double-splat work?
- Should protocols dispatch only on one argument or multiple?
- How much Clojure sequence behavior should be copied?
- How should async/concurrency libraries look?
- Should Boron eventually generate Ruby AST directly?
- Is direct YARV generation ever worth doing?
- Should Boron eventually self-host?

Document decisions when evidence accumulates.

---

# 63. Example of the intended feel

Eventually, Boron might plausibly support code like:

```clojure
(require "sinatra/base")
(require "json")

(ns example.web)

(defn json [value]
  (JSON.generate value))

(defn active? [user]
  (.active? user))

(defclass App < Sinatra::Base

  (before
    (content-type :json))

  (get "/health"
    (json {:status "ok"}))

  (get "/users"
    (->> (User.all)
         (filter active?)
         (map
           (fn [user]
             {:id (.id user)
              :name (.name user)}))
         json))

  (get "/users/:id"
    (if-let [user (User.find-by :id (get params :id))]
      (json
        {:id (.id user)
         :name (.name user)})
      (do
        (status 404)
        (json {:error "not found"})))))
```

This example is aspirational.

Do not implement every construct shown here immediately.

It exists to illustrate the target feel:

- unmistakably Lisp
- unmistakably integrated with Ruby
- functional where useful
- comfortable with objects
- minimal ceremony around Ruby libraries

---

# 64. Success criteria

Boron succeeds if:

A Ruby programmer can learn the core language quickly.

A Lisp programmer recognizes it as a real Lisp.

A user can require an arbitrary Ruby gem and interact with it without a bespoke wrapper.

Macros can introduce meaningful new abstractions.

Classes feel natural without dominating the language.

Functional data transformation feels excellent.

Generated Ruby remains inspectable.

The runtime remains mostly Ruby rather than becoming an accidental second Ruby implementation.

The language becomes useful enough that writing a real tool in Boron feels reasonable rather than performative.

---

# 65. The manifesto

Ruby is already unusually close to Lisp.

It has closures.

It has symbols.

It has dynamic dispatch.

It has classes that are objects.

It has open classes.

It has reflection.

It has garbage collection.

It has metaprogramming.

It has a culture that values expressive code.

But Ruby's metaprogramming mostly occurs inside the language Ruby already decided to be.

Boron introduces another layer.

In Boron, programs are forms.

Forms are data.

Syntax can be transformed before Ruby sees it.

Lexical functions coexist with dynamic object dispatch.

Classes are runtime values that Lisp macros can construct and reshape.

Existing Ruby libraries become the native ecosystem of a different language.

We are not trying to disguise Ruby.

We are not trying to recreate Scheme.

We are not trying to prove that Lisp is purer than object-oriented programming.

We are trying to discover what happens when two unusually expressive traditions are allowed to meet cleanly.

Ruby provides objects, libraries, operating-system access, garbage collection, networking, databases, web frameworks, and decades of practical engineering.

Lisp provides programmable syntax, explicit structure, lexical composition, macros, code as data, and a tradition of making the language itself available to the programmer.

Boron should preserve the strengths of both.

The boundary should remain visible.

That boundary is where the interesting language lives.

**Ruby provides the world.**

**Lisp provides the way we think inside it.**

That is Boron.