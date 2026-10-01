# Test audit: macros, interop, and declarations

October 1, 2026. Applied the is-it-tested skill by walking the reader → expansion
→ lowering → emitted Ruby boundary, plus Ruby constants, block conversion,
SQLite persistence, and editor tokenization. This is a focused audit of the recent
language slices, not a claim that all possible programs are covered.

| Failure consequence | Existing guards | Audit result |
| --- | --- | --- |
| Silent wrong expansion or accidental capture | macros_test: quote/form distinctions, nested quasiquote, lazy core macros, gensym (including identical printed names), phase isolation | Principal semantics covered; full automatic hygiene is not implemented |
| Misleading macro failure location or runaway expansion nesting | macros_test: original argument spans, generated call spans, macro exceptions, depth limit | Covered for stored spans; runtime source maps remain future work |
| Wrong block/argument conversion or repeated side effects | explicit_block_send_test: positional Proc stays an argument, nil/to_proc conversion, evaluation order, invalid marker placement, emitted execution | Covered |
| Ordinary `&` functions rejected or confused with block/rest syntax | New coexistence test: def/let/set! bindings, real Set intersection, method blocks, rest parameters, emitted Ruby, missing builtin binding | Found rejection in binding validation; fixed and observed failing before the fix |
| Replacing a Ruby constant or changing an existing superclass | class_declarations_test: declaration reuse, type conflicts, superclass mismatch, inherited constants, missing parent namespaces | Covered for sequential declarations |
| Database data lost or routes serving stale/wrong results | sqlite_web/app_test: temporary file database, JSON/404 results, changed rows, reload persistence, compiled subprocess | Covered for the example's read-only routes |
| Editor misrepresents implemented syntax or misses a nested example | grammar.cjs: actual TextMate engine, declarations/macros, contextual ampersand scopes, definition names, all examples including sqlite_web/app.bn | Added focused scope cases and nested example traversal |

The independent subagent code review found the ampersand-binding defect and no
additional correctness findings in the reviewed macro, declaration, block-send,
packaging, and web changes. Review is complementary to executable tests, not proof
that no further defects exist.

## Remaining limits

The root CI matrix runs lint and core Minitests on Ruby 3.3/3.4/4.0.
Separate CI jobs run web integration on Ruby 4.0 and tokenizer tests with stable
VS Code. The gem build waits for all of these checks. Local execution was on Ruby
4.0.7; the expanded CI matrix has not been run from this session.
Editor testing uses the installed VS Code engine rather than adding npm packages.

No tests yet guard concurrent declaration races, arbitrary parser/macro fuzzing,
or performance regressions. Macro nesting has a limit; arbitrary macro body
execution does not have a timeout. The web example has no write/request-input
routes, so CRUD validation and concurrent schema migration are outside this
slice. Add specific guards as those behaviors are designed rather than claiming
coverage from the passing read-only integration tests.

## Local verification

From the repository root, run StandardRB before Minitest:

```sh
bundle exec standardrb
bundle exec ruby -Itest test/all_test.rb
BUNDLE_GEMFILE=examples/sqlite_web/Gemfile BUNDLE_PATH=vendor/bundle bundle exec ruby examples/sqlite_web/app_test.rb
ELECTRON_RUN_AS_NODE=1 /usr/share/code/code editors/vscode/test/grammar.cjs
```

The optional example bundle must be installed first using its README. No new test
framework, coverage package, or runtime dependency was needed for this audit.
