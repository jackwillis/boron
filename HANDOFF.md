# Boron implementation handoff / memory dump

Updated October 1, 2026 (America/Chicago). This records the implemented system,
accepted design decisions, validation, and remaining work. It supplements the
language reference; SPEC.md remains the original aspirational proposal.

## User intent and workflow

Jack Willis is building a minimal Lisp hosted on Ruby. Keep core dependencies
minimal, use Minitest and TDD for language semantics, and run StandardRB before
Minitest. Commit completed slices frequently. Git identity requested by the user:
Jack Willis <jack@attac.us>. Do not publish, deploy, push, or select a license
without a corresponding request. A concurrent session selected the MIT license
and committed LICENSE as part of 135f20f; preserve that committed project choice.

Discuss speculative syntax before implementing it. The user explicitly requested
more discussion and welcomes pushback. Preserve edits from other sessions sharing
this checkout; only stage work belonging to this task. At this handoff, another
session's additions in test/cli_test.rb, test/compiler_test.rb, test/reader_test.rb,
and minor README edits were deliberately preserved rather than swept into commits.
Recheck git status and recent commits before assuming this list is still current.

The user tried moving the web database initialization under --serve, then explicitly
authorized reverting that edit. The committed app initializes its schema/data when
loaded; only server startup is gated by --serve. No web server remains running from
our smoke tests. Generated gem/database/vendor files are ignored.

## Environment and packaging

Workspace: `/home/jack/code/boron`, Fedora, Ruby 4.0.7. Current branch: main.
The repository and gem metadata point to https://github.com/jackwillis/boron.
Gem version: 0.1.0. Supported minimum: Ruby 3.3 (Data is used). CI covers
3.3, 3.4, and 4.0, including Debian 13's Ruby version, on Ubuntu runners. The
configured matrix has not been run remotely by this task. Local results are Ruby
4.0 only; no local multi-version execution is claimed.

Core runtime has no external gem dependencies. Development Gemfile uses Minitest 5
and StandardRB. Bundler installs locally into vendor/bundle. Ruby Set is loaded when
not already available. The optional web Gemfile has its own vendor/bundle and lock:
ActiveRecord 8.1.4, Sinatra 4.2.1, sqlite3 2.9.6, Puma 8.0.2, Rack/Rackup, Minitest.
These do not become dependencies of the Boron gem.

The gem packages lib Ruby files plus lib/boron/core.bn, bin/boron, top-level examples,
and selected language docs. Nested optional web files and editor files are checkout
resources. The CI CD job builds only; no upload or publishing. The gem includes
LICENSE and declares MIT. Separate web and stable-VS-Code tokenizer jobs gate CD
alongside the Ruby matrix. These CI jobs were added by the concurrent session.

## Architecture and source representation

Pipeline: Reader → Expander → Lower → typed RubyIR → RubyEmitter → Ruby execution.
There is no separate interpreter, alternate backend, or source-string assembly in
Lower. Session uses Kernel.eval of emitted Ruby. Compiler can emit a standalone
program with `require "boron"` and a fresh Environment. Host Ruby libraries and
constants are shared; session Boron bindings and macro registries are independent.

SourceSpan stores filename, character offsets (zero based, exclusive end), and
one-based line/column positions. Columns count characters, not bytes/cells. Syntax
contains datum/span/optional MacroOrigin. Identifiers differ from Ruby Symbols.
Form::List/Vector/Map/Set contain structural children; containers and identifier
names are frozen. Literal runtime values and unquoted collections use Ruby objects.
Do not confuse runtime Arrays with code lists or promise persistent/deeply immutable
runtime collections.

Reader handles nested collections, symbols, decimal integers/floats, true/false/nil,
strings with n/r/t/quote/backslash escapes, and semicolon comments. No string
interpolation. It recognizes .[] and .[]= as method identifiers. Prefixes ', `, ~,
and ~@ desugar with real source spans. IncompleteInput is a ReadError subclass for
unfinished delimiters, strings, and prefixes, used by the REPL. Unexpected closers
and invalid escapes remain immediate failures. Maps require alternating forms.

## Lexical semantics

Environment stores bindings by name; generated identifiers use a distinct key type.
Def writes the root session binding. Set! changes the nearest existing binding.
Globals resolve at call time for recursion/redefinition. Let is sequential: each
binding gets a new child frame, so earlier closures cannot see later bindings.
Duplicate let/parameter bindings are rejected. Fn is a strict Ruby lambda, supports
[x & xs] rest arguments, and returns its final expression. Empty bodies return nil.
If uses Ruby truth (only false/nil falsey) and evaluates one branch. Do is a sequence.

Operators are ordinary callable bindings, including +, *, -, /, %, and comparisons.
They can be shadowed; integer division is Ruby division. RubyIR models literal/local,
assignment/call, array/hash, sequence/conditional, and lambda nodes. Emitter-generated
local names avoid user-name injection. Literal strings are frozen; explicit .dup
allocates fresh mutable copies. Host-created strings keep their own mutability.
Arrays/Hashes/Sets are actual Ruby collections. Input evaluation order follows Ruby.

Unbound uppercase paths resolve exact Ruby constants from Object, with explicit
nested lookup and no inherited constant traversal. Boron bindings take precedence.
(.method receiver args...) uses public_send with the exact Ruby method spelling.
Private methods are not implicit. Require delegates to Ruby's actual loader.

## Syntax decisions to retain

- Ruby implementation names: snake_case. Boron-facing bindings: kebab-case.
  Do not automatically translate host method spellings.
- Block surface: `(.method receiver args... & block)`. Exactly one final expression
  follows the marker. Ordinary Proc arguments remain positional without it.
- The existing send-with-block(receiver, method, argsArray, block) supports dynamic
  method selection. No send& alias or .method& shorthand was retained.
- Do as a block marker was discussed, not accepted/implemented. Do remains a
  list-head sequence form. Ampersand is contextual, not globally reserved.
- Ordinary `(& left right)` can call a user-defined binding; there is no builtin &.
  Def/let/set! accept &, while fn parameter vectors use it as the rest marker.
- Hashes stay positional arguments. Explicit keywords, splats, block forwarding,
  destructuring, and implicit receiver lookup are not implemented.

## Macros and quotation

Expander runs bundled core.bn macros in a separate compile-time Environment. Macro
inputs/outputs are Form datums; SyntaxData captures reusable structural argument
origins and wraps results. Runtime Array/Hash results are rejected as code. Literal
values have no individual origin via object identity. Generated nodes use the real
macro call span and origin metadata, never a fake expansion source file.

Top-level defmacro processes definitions in source order. Macros persist within a
Session but not across sessions. Runtime def bindings are unavailable in macro
bodies. Macro functions compile through the same backend, then expansion precedes
lowering. Quote protects code from expansion. Quasiquote tracks nesting; active
unquote evaluates, active splice accepts Form lists/vectors or Arrays. Quoted vectors
remain Form::Vector, not runtime Array. Macroexpand accepts one syntactically quoted
form, recursively expands it, and returns its datum without running the result.

Bundled macros: defn, when, unless, defclass, defmodule. Supporting bindings include
list/vector/list?/first/rest/cons/concat/apply/gensym. Gensym keys differ from plain
identifiers of the same printed name; macros are not automatically hygienic. There
is a 100 nested expansion-call limit, not an execution timeout or sandbox.

## Named Ruby declarations and instance context

`(defmodule Name)`, `(defclass Name)`, and `(defclass Name < Superclass)` are macros
that emit Runtime declaration helper calls. Names are unquoted uppercase paths.
Parents must already exist. New classes default to Object. Superclass expressions
run once and must return Class. Repeated matching declarations return the existing
object; explicit superclass mismatch or conflicting constant types raise TypeError.
Declarations affect shared Ruby constants, not a second Boron binding. No bodies,
slots, implicit self, or automatic namespace creation are implemented.

`with-self` wraps a callable in a Ruby Proc. A host that rebinds block self supplies
its actual execution instance as the function's first positional argument; remaining
host positional arguments follow. Lexical captures and strict function arity remain.
It works with instance_exec, define_method, and Sinatra's route method installation.
Self is an ordinary parameter name. It does not infer the receiver of ordinary
block-yielding calls, and it does not add keyword/block forwarding. This is the
current explicit model before designing class-body/method sugar.

## Diagnostics and REPL

Diagnostic/Label values separate source error data from rendering. Reader and
CompileError retain location-prefixed message/class APIs and expose diagnostic/span.
Kinds distinguish reader, expansion, compile. SourceRegistry snapshots text and is
exposed by Compiler and Session. Renderer handles excerpts, EOF, CRLF, character
columns, missing-source fallback, multiple labels, notes/help, and multiline notes.
Duplicate bindings label both sites. Audit fixed mutable Label messages; review fixed
label text disappearing when source is missing. See DIAGNOSTICS.md for limits.

Ruby runtime exceptions remain native. UnboundName includes location text, but no
runtime excerpt wrapper/source map is implemented. No diagnostic JSON, codes,
suggestions, backtrace flag, or expansion-chain trace exists yet.

`boron repl` uses one Session, reader-driven multiline buffering, tty prompts, and
commands :help/:quit/:exit when no form is buffered. It prints completed results with
Printer, recovers after ordinary errors, clears interrupted input/evaluation, and
reports incomplete input at EOF with status 1. Normal EOF returns 0. No readline
history/completion. Evaluation is not transactional; prior side effects/macros may
remain after an error. SystemExit is not swallowed. Printer handles form/container
cycles and limits depth; host inspect and display are not round-trip serialization.

## Useful programs

User report: `./bin/boron run examples/user_report.bn -- examples/users.json`.
Reads a JSON array, validates optional string/null name/role fields, filters active
records, groups role counts, and prints JSON. Eager helpers map/filter/reduce/group-by/
count use Ruby Enumerable; callbacks on Hash see a single [key,value] element.

Web app: examples/sqlite_web/README.md documents its separate bundle. It names a
module/model/app, creates and seeds a users table on first load, preserves subsequent
rows, and serves JSON /health, /users, /users/:id. With-self exposes request params.
IDs must be positive decimal strings; missing/malformed users get JSON 404. Queries
use actual ActiveRecord. This is read-only, with no migrations, CRUD/auth system,
concurrent schema bootstrap guarantee, or Boron replacement for Sinatra/SQLite.
Loading initializes the app/database; --serve starts Puma bound to localhost:4567.

## Verification and audit

Run lint before tests:

```sh
RUBOCOP_CACHE_ROOT=/tmp/boron-rubocop-cache bundle exec standardrb
bundle exec ruby -Itest test/all_test.rb
BUNDLE_GEMFILE=examples/sqlite_web/Gemfile BUNDLE_PATH=vendor/bundle bundle exec ruby examples/sqlite_web/app_test.rb
ELECTRON_RUN_AS_NODE=1 /usr/share/code/code editors/vscode/test/grammar.cjs
gem build boron.gemspec
```

The optional bundle must be installed first. The VS Code harness uses installed
TextMate/Oniguruma engines without npm dependencies. It covers contexts, declaration
names/macros, & roles, with-self, and all examples including the nested web app.

Local core results include concurrent test additions that are intentionally not
part of our commits. Latest results and scope limits are in TESTING.md. The skill
used was is-it-tested from the user's local break-things plugin source. Targeted
failing tests preceded implementations; the audit added EOF/prompt/interrupt/cycle,
callback-reuse, ID-prefix, compiled-route, and immutable-label guards. The subagent
review found missing-source label loss; d0e0454 fixes it and reviewer verification
reported no remaining concern. Earlier review found & binding rejection, fixed in
a1b8ec0. Review and passing tests do not establish exhaustive correctness.

## Commit trail for the current work

- 71e1a83: diagnostic data, source registry/renderer, duplicate labels.
- 8806fb2: multiline persistent REPL and printer.
- ecd07b7: explicit with-self and individual-user route.
- 4451003: failure-mode audit guards and immutable Label messages.
- d0e0454: review fix preserving labels without source text.

An independent session committed README onboarding work as d75b316 and MIT,
Ruby >=3.3, plus expanded CI as 135f20f. Preserve
that work when refreshing docs. Current git state, not this record, is authoritative.

## Next priorities and unresolved decisions

Runtime source context with native causes/debugging; explicit keyword/splat/block
forwarding; then discuss method/class-body syntax before implementing it. Web/editor CI jobs are configured, but their remote execution remains unverified.
REPL history, conservative suggestions,
JSON diagnostics, expansion traces, parser fuzzing, automatic hygiene, and performance
measurement are later work. Broader namespaces, protocols, Rails, self-hosting,
persistent collections, proper tail calls, and alternate VM backends remain proposals.

## Latest user steering: Boron-first tooling

The user wants, at a later point, a Boron-first test library, project startup and
organization, Bundler integration, and possibly a Rake replacement DSL. These are
recorded in ROADMAP.md, not implemented during this slice. Suggested ordering:
native test API on optional Minitest, project scaffold with normal Gemfile, bundle-
aware run/test behavior, then a task DSL initially using Rake. Public command and
DSL names remain undecided. Keep the compiler's Ruby Minitest suite and avoid a
new dependency resolver, mandatory development gems, or unrequested scaffolding.

## Final validation snapshot

107 core tests / 692 assertions, 4 optional web tests / 22 assertions, and 41
TextMate scope assertions plus extension checks passed on Ruby 4.0.7. StandardRB
passed. Gem build and temporary-directory local installation succeeded; the
installed REPL executed `(defn square [x] (* x x))` and `(square 9)` returned 81.
No gem was uploaded and no server was left running. Documentation changes and
future-tooling notes do not imply additional implemented commands.

## String-literal policy revision

The user reconsidered mutable literals and explicitly approved frozen literals
with mutable String objects still available. Commit 7dfca4a removes the emitter's
automatic .dup, retains the frozen-string directive, and tests literals/quotation,
explicit copies, host String results, compiled programs, metadata, and REPL errors.
String-literal conditions emit true to avoid Ruby parser warnings while preserving
truth semantics. Runtime .dup remains explicit; no unary-plus shortcut, per-file
switch, deep collection freeze, or extra string IR node was introduced. This
supersedes the earlier fresh-mutable-literal contract. Other-session collection
freshness tests now request an explicit copy when they mutate a string.
