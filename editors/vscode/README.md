# Boron for VS Code

A declarative extension for Boron syntax highlighting and basic editing. There
is no JavaScript extension host code, npm dependency, build step, or language server.
The JavaScript file under `test/` is only a development test harness.

## Load locally

From the Boron repository root:

```sh
code --new-window --extensionDevelopmentPath="$PWD/editors/vscode" "$PWD"
```

Open an example `.bn` file in the development window. Alternatively, open
`editors/vscode` as a workspace and press F5 with its supplied launch configuration.
The extension recognizes `.bn` and `.boron`, or select **Boron** as the file's
language mode. This is local development loading, not a Marketplace publication.

## Highlighting design

The grammar uses standard TextMate scopes so existing themes supply the colors.

| Construct | Scope |
| --- | --- |
| Core forms and bundled macros in call-head position | `keyword.control.boron` |
| Name immediately following `def`, `defn`, or `defmacro` on the same line | `variable.other.definition.boron` |
| Ordinary call head | `entity.name.function.boron` |
| Builtin call head | `support.function.boron` |
| Arithmetic/comparison call head | `keyword.operator.boron` |
| Explicit Ruby method send, including `.[]`/`.[]=` | `entity.name.function.member.boron` |
| Uppercase Ruby constant path | `support.class.boron` |
| Other identifiers | `variable.other.boron` |
| Standalone `&` outside a call head | `keyword.operator.boron` |
| Ruby Symbol literal | `constant.other.symbol.boron` |
| Numbers, booleans, nil | `constant.numeric` / `constant.language` |
| Strings, escapes, comments | Standard string/escape/comment scopes |

Core forms are colored only in a list's head, including heads placed after comments
or on a subsequent line. Lists/collections nest recursively. Strings do not embed
Ruby interpolation; `#{...}` inside a string stays string text. Unknown string
escapes are marked invalid. Implemented quote/quasiquote/unquote/splice prefixes
have punctuation scopes. Bundled defn/when/unless/defclass/defmodule and the
macro-definition/inspection forms have keyword scopes. Class and module names
remain Ruby constant paths; declarations currently have no bodies.

The same `&` token introduces rest parameters or the final block in a method send.
At an ordinary call head, `(& left right)` receives the ordinary function scope;
it can call a user-defined binding, but Boron supplies no builtin `&` yet. The
proposed `do` block marker, send& alias, and .method& shorthand are not language
features. `(do ...)` keeps its sequence-form meaning.

TextMate is lexical highlighting. It cannot determine whether a name is bound,
whether `+` has been shadowed, or whether an uppercase name denotes a Boron binding
rather than a Ruby constant. Coloring does not imply static validation.

Language configuration adds `;` comments, bracket matching, auto-closing and
surrounding pairs, Lisp-friendly word selection, and optional `; region` /
`; endregion` folding markers. Quotes used as reader prefixes are not auto-paired.
The grammar excludes `.[]`/`.[]=` tokens from bracket matching. Structural
indentation, completion, formatting, and diagnostics await language tooling.

## Verify with VS Code's tokenizer

On this Fedora installation, from the repository root:

```sh
ELECTRON_RUN_AS_NODE=1 /usr/share/code/code editors/vscode/test/grammar.cjs
```

The harness uses the TextMate/Oniguruma engines and WASM shipped with VS Code.
It checks scopes, multiline nesting, escaped strings, configuration, and all
repository examples, including the nested SQLite web app. No test packages are downloaded. With another installation,
use its actual Electron executable; if needed set `BORON_VSCODE_MODULES` to its
`resources/app/node_modules.asar` (or unpacked node_modules directory).

For visual inspection, use VS Code's **Developer: Inspect Editor Tokens and
Scopes** command. Exact colors depend on the chosen theme.

References: [syntax highlighting](https://code.visualstudio.com/api/language-extensions/syntax-highlight-guide),
[language configuration](https://code.visualstudio.com/api/language-extensions/language-configuration-guide).
