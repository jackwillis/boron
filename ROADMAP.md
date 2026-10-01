# Triage and milestones

The original proposal is in SPEC.md. Work is ordered by prerequisites and lands
in small, test-driven slices. Future syntax examples are not implemented promises.

| Priority | Milestone | Acceptance criterion | Status |
| --- | --- | --- | --- |
| P0.1 | Reader foundation | Nested lists, identifiers, numbers, comments, source spans | Complete |
| P0.2 | Reader literals | Strings/escapes, booleans, nil, Symbols, vectors, maps, sets | Complete |
| P0.3 | First compiler | Ruby IR and emitter; arithmetic executes to `7` | Complete |
| P0.4 | CLI | Run `.bn` files, emit runnable Ruby, useful error status | Complete |
| P1 | Lexical language | Definitions, sequential let, functions, calls, conditionals, closures, recursion | Complete |
| P2 | Initial Ruby interop | Explicit sends, constants, require, real JSON library | Complete for this slice |
| P3 | Macros | Quote, quasiquote, expansion, defmacro, macroexpand, gensym | Complete for this slice |
| P4 | Ruby blocks | Explicit block passing with Enumerable and File.open | Explicit call-site & marker complete |
| P5 | Classes | Real Class values, methods, state; macro sugar follows primitives | Named defclass/defmodule complete; bodies/methods deferred |
| P6–P7 | Usability and ecosystem | REPL, core macros/sequence helpers, real gem examples | Sequence helpers, REPL, and gem example complete |
| P8+ | Further abstractions/tooling | Protocols, editor tooling; optional backend experiments | Deferred |

## Completed bootstrap acceptance

- [x] Read all initial literal categories with source locations.
- [x] Lower through typed Ruby IR rather than scattered Ruby strings.
- [x] Arithmetic expression returns `7`; operators remain shadowable bindings.
- [x] Make-adder returns `7`; functions are strict Ruby lambdas and support rest arguments.
- [x] Closures retain bindings, including mutation; sequential let has lexical visibility.
- [x] Session globals persist across evaluations and permit recursion.
- [x] Ruby Arrays, Hashes, Sets, constants, constructor calls, mutation, and JSON interop.
- [x] Explicit block passing; a Proc argument stays an argument.
- [x] File.open block closes its host file after execution.
- [x] CLI run and compile, standalone emitted-program execution, diagnostics/exit codes.
- [x] Tests observed failing before new reader, compiler, and CLI implementations.
- [x] VS Code highlighting/configuration, tested with VS Code's TextMate engine.
- [x] StandardRB development tooling and an informal language spec in LANGUAGE.md.

Validation on September 30, 2026: Ruby 4.0.7, Minitest 5.27.0; 35 tests and
193 assertions pass. The examples run through the executable, and the compiler's
emitted Ruby runs with `ruby -Ilib`. Minitest is not needed for those programs.

## Completed macro slice

The first useful program is complete: `examples/user_report.bn` reads a JSON
file, filters active users, and summarizes names and role counts. Its five sequence
helpers (`map`, `filter`, `reduce`, `group-by`, `count`) work with Ruby Enumerable.
CLI program arguments are routed explicitly after `--`. Integration tests cover
the report's results, failures, and compiled execution. Quotation and macros are
now implemented; a SQLite/ActiveRecord/Sinatra example is complete. the REPL and first structured diagnostic slice are complete.

The quotation/data API is implemented. Macro inputs and outputs must be forms, while
syntax objects retain source context. Do not confuse runtime Arrays with code
lists or discard source spans accidentally.

Acceptance criteria:

- Reader shorthand for quote, quasiquote, unquote, and splice.
- Explicit compile-time macro environment and definition ordering.
- Recursive expansion before lowering, with inspectable macroexpand output.
- Variadic defmacro and gensym; expansion errors include call-site context.
- Implement `when`, `unless`, and `defn` through macros.
- End-to-end tests for nested quasiquotes and accidental binding capture.

## Remaining design questions

- Core special-form names are reserved against macro redefinition; revisit other
  binding shadowing only with an explicit policy.
- Design keyword/splat arguments; do not automatically reinterpret every Hash.
- Block sends use `(.method receiver args... & block)`; more DSL sugar can
  build on the existing primitive.
- Define exception forms over Ruby's exception machinery.
- Plan source maps for generated Ruby backtraces.
- Design class/module bodies and method sugar over the working explicit-self bridge.

Destructuring, namespaces, persistent collections, protocols, self-hosting, Rails,
direct YARV, and optimization remain outside the bootstrap scope.

## Completed tonight

- Structured reader/expansion/compile diagnostics, snapshot excerpts, and duplicate labels.
- Persistent multiline REPL, commands, EOF handling, prompts, and error recovery.
- Explicit with-self bridge, Ruby method installation through define_method, and
  Sinatra `/users/:id` backed by ActiveRecord with JSON 404 behavior.
- Failure-space audit and independent code review; see TESTING.md.
- Frozen string literals with explicit mutable copies; host String mutability preserved.

## Next bounded work

1. Runtime source context and a backtrace/debug mode, preserving Ruby exceptions.
2. Explicit keyword/splat/block forwarding semantics before more gem DSLs.
3. Discuss method/class-body syntax over the existing primitives, with explicit
   self as the current model. Add write routes only with request validation and
   persistence tests.

REPL history/completion, automatic hygiene, full expansion traces, parser fuzzing,
and performance measurement are later improvements. Web/editor CI jobs are configured. Keep the optional
web bundle separate. See HANDOFF.md for a comprehensive implementation handoff.

## Boron-first project ecosystem (requested)

Users need to write tests, start projects, select gems, and automate work in Boron.
This is planned work, not implemented CLI commands or libraries. Preserve minimal
core dependencies and build on the Ruby ecosystem before replacing its machinery.

1. **Boron-first tests:** a small language API for named tests, assertions, fixture
   hooks, failures, and source locations, initially backed by Minitest. The compiler
   implementation continues to use Ruby Minitest. Define isolation and assertion
   semantics before choosing macros or syntax; test error reporting as well as passing
   assertions. Keep the test adapter an optional development dependency.
2. **Project starter:** a minimal project layout, entrypoint, tests, Gemfile, README,
   and ignore rules. Decide local-app vs gem/library layouts explicitly. Preserve
   existing files; avoid imposing Rails structure or a second package format.
3. **Bundler integration:** honor each project's Gemfile/lock and run/test under its
   selected bundle. Reuse Bundler resolution/install and RubyGems packaging. Decide
   working-directory discovery, executable commands, dependency groups, and standalone
   emitted-program behavior. No custom resolver or implicit gem downloads.
4. **Task DSL:** consider Boron task definitions, prerequisites, and descriptions
   over Rake first, preserving mature file-task behavior. A standalone Rake replacement
   is a later decision requiring a concrete benefit and compatibility tests.

These are the next usability layer after source diagnostics and explicit Ruby interop.
Proposed command names such as `boron new` / `boron test` and DSL spellings require
user discussion; they are not current commands. See DESIGN.md and HANDOFF.md.
