# Diagnostics: implemented slice and next work

## Implemented

Reader, expansion, and lowering failures carry an immutable Diagnostic with kind,
message, primary_span, labels, notes, help, and cause fields. ReadError and
CompileError retain their classes and concise location-prefixed messages for
Ruby callers. Their diagnostic field separates data from presentation. Expansion
uses kind `:expansion`; the other phases use `:reader` and `:compile`.

Label messages, diagnostic strings, and label/note arrays are copied and frozen.
Compiler and Session expose SourceRegistry snapshots through `sources`;
DiagnosticRenderer accepts a registry. The CLI and REPL print plain-text excerpts,
carets, labels, notes, and help. Duplicate let bindings and fn parameters label
both the first binding and the duplicate. Missing source still yields a useful
location. EOF spans receive a caret; multiline spans display the first line and
an explicit continuation note. Columns count Unicode characters, not terminal
cell widths. CRLF line endings are handled, and tabs in caret prefixes are retained.

```ruby
compiler = Boron::Compiler.new
begin
  compiler.compile("(let [x 1 x 2] x)", filename: "demo.bn")
rescue Boron::CompileError => error
  warn Boron::DiagnosticRenderer.new(compiler.sources).render(error.diagnostic)
end
```

The source registry stores the evaluated text instead of rereading a file that
might have changed. REPL submissions get distinct `(repl:N)` filenames. A direct
Reader consumer can populate its own registry before rendering an error.

## Runtime and macro context

Ruby runtime exceptions keep their original classes, messages, and host stacks.
UnboundName retains its source-location message. Neither currently has a source
excerpt or structured runtime diagnostic. No source map is implied by the reader
and compile renderer. Diagnostic.cause is available for future structured runtime
integration; preserving native exception causality remains a requirement.

Macro-generated syntax uses the actual call span plus MacroOrigin metadata.
Reused structural input objects retain input spans. Literal values do not carry
individual provenance through object identity. There is no fabricated expansion
source file or complete expansion-chain trace. The nesting limit bounds recursive
expansion, not the execution time of a macro body.

## Next bounded work

1. Add source-aware runtime call/send context through typed IR or narrow helpers,
   preserving native Ruby causes, evaluation order, arity, and SystemExit.
2. Introduce stable codes and a debug/backtrace mode without confusing CLI options
   with program arguments after `--`.
3. Retain full nested expansion provenance before rendering expansion traces.
4. Add conservative spelling suggestions, JSON output, and editor integration
   only after the data boundary is sufficient.

No diagnostic-format, backtrace, or expand-trace flags are implemented yet.
Warnings and wide-character terminal alignment are future work. See TESTING.md
for the failure-mode audit and HANDOFF.md for implementation context.
