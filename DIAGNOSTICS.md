# Error-system design notes (proposal)

The October 1 ChatGPT aside proposes errors as a language feature. Adopt its
central goal: explain what failed, where, how Boron interpreted the form, and
what correction is useful. The following is planned work, not current CLI syntax.

## Current foundation

Syntax has SourceSpan and optional MacroOrigin. Reader and CompileError expose
spans; binding failures carry locations in their messages. The CLI prints concise
messages. Runtime Ruby exceptions keep their native classes. Generated Ruby
backtraces are not mapped to Boron source. Macro-generated nodes use an actual
call span; reused structural input forms retain input spans. Do not invent a
`<macro expansion>` file unless there is an actual stored expansion to display.

## First implementation slice

Introduce immutable Diagnostic and Label values carrying phase, message,
primary span, additional labels, notes, help, and cause. Keep rendering out of
exception constructors. Add a source registry for each compile/evaluate input so
rendering works for files and session strings without rereading changed files.
Build a plain-text excerpt/caret renderer, then integrate reader/lowering errors
and duplicate-binding labels. Preserve existing exception classes and useful
message compatibility while introducing structured fields.

Use TDD for Unicode columns, CRLF, missing source, zero-length/end-of-file spans,
multi-line forms, duplicate bindings, and redirected CLI output. Avoid color and
terminal dependencies in this first slice.

## Runtime and macro context

Carry source context through IR or narrow runtime helpers around calls/sends.
Preserve the original Ruby exception as the cause and expose its stack in an
explicit debug mode. Evaluate each receiver and argument once; preserve evaluation
order, strict lambda arity, SystemExit, and normal interop behavior. Do not wrap
all Ruby code so broadly that a programmer cannot recognize host failures.

Retain expansion provenance across nested expansions before designing a trace
renderer. Show the macro invocation and original argument where available; use
stored expansion data for generated-form excerpts. Macro expansion currently has
a nesting limit but no execution timeout; rich diagnostics do not change that.

## Later slices and open decisions

- Stable codes grouped by reader, macro, lowering, binding, and interop phases.
  The suggested BR/BE/BC/BM/BI numbers are examples, not assigned codes.
- Conservative suggestions from visible lexical/global bindings and Ruby methods.
- JSON diagnostic output and editor integration built from the same data.
- Optional backtrace and expansion-trace CLI controls, with compiler options
  distinguished from program arguments after `--`.
- Warnings using the same infrastructure if concrete warning cases emerge.

No new diagnostic flags or codes are implemented yet. Prioritize structured data,
source excerpts, and multiple spans before spelling suggestions or LSP work.
