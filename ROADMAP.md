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
| P3 | Macros | Quote, quasiquote, expansion, defmacro, macroexpand, gensym | Next |
| P4 | Ruby blocks | Explicit block passing with Enumerable and File.open | Primitive complete; surface syntax deferred |
| P5 | Classes | Real Class values, methods, state; macro sugar follows primitives | Planned |
| P6–P7 | Usability and ecosystem | REPL, core macros/sequence helpers, real gem examples | Planned |
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

## Next slice: macro design before implementation

Decide a quotation/data API first. Macro inputs and outputs must be forms, while
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

- Reserve core special-form names or define an explicit shadowing policy.
- Design keyword/splat arguments; do not automatically reinterpret every Hash.
- Choose block syntax over the working `send-with-block` primitive.
- Define exception forms over Ruby's exception machinery.
- Plan source maps for generated Ruby backtraces.
- Design class/method primitives only after macros are established.

Destructuring, namespaces, persistent collections, protocols, self-hosting, Rails,
direct YARV, and optimization remain outside the bootstrap scope.
