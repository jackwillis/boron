# Bootstrap decisions

## Architecture

Current pipeline: reader → semantic lowering → Ruby IR → Ruby emitter → Ruby
execution. Expansion will go between the reader and lowering when macros land.
There is no separate evaluator interpreting Boron forms.

Ruby provides the values: Integer, Float, String, Symbol, Array, Hash, Set,
Proc, classes/modules, and host exceptions. Syntax representation is separate
from these runtime values.

## Reader and source metadata

`Reader.new(source, filename: "...").read_all` returns an Array of `Syntax`
objects. Each contains a datum and `SourceSpan`. Structural datums are
`Form::Identifier`, `Form::List`, `Form::Vector`, `Form::Map`, and `Form::Set`.
Collections contain child syntax objects. Other datums use Ruby literal values.

Identifiers are distinct from Ruby Symbols. Syntax and structural data are
immutable; runtime collections and emitted strings are mutable Ruby values.

Spans carry filename, zero-based character offsets, and one-based line/column
positions. Ends are exclusive. LF advances the line; CRLF works as whitespace
followed by LF. Columns count characters, not display cells or bytes.

Whitespace separates atoms; `;` comments continue to LF or EOF. Lists, vectors,
maps, and sets use their proposed delimiters. Maps require an even number of
forms. Any form can be a map key. Strings support newline, carriage return, tab,
quote, and backslash escapes. Unknown escapes are errors; interpolation is not
implemented. Quotation prefixes still produce explicit unsupported-syntax errors.

Integer tokens accept optional signs and decimal digits. Float tokens accept a
fraction and/or exponent, with digits on both sides of any decimal point.
Non-finite float literals are rejected. Numeric-looking spellings outside these
rules are identifiers for now. `true`, `false`, `nil` are literal tokens.
Symbol literals use `:name`; quoted-symbol syntax is not supported.
`Foo::Bar` remains an identifier in the reader. `.[]` and `.[]=` are recognized
as method identifiers despite containing collection delimiters.

Unclosed collections report their opening delimiter; unexpected closers report
their own location. Read and compile errors include source locations.

## Bindings and calls

`(f x)` invokes the callable Boron value bound to `f`. `(.foo receiver x)` calls
Ruby `public_send(:foo, x)`. Private Ruby methods are not implicitly accessible.
The builtin `require` deliberately delegates to Ruby's Kernel.require.

Operators are ordinary Proc bindings, using Ruby methods internally. There is
no arithmetic specialization yet: lowering must preserve shadowing of `+` and
other builtins. Binary arithmetic inherits host behavior, including integer
division. `+` and `*` accept zero arguments (0 and 1), `-` accepts unary negation,
`/` requires at least two arguments, comparisons require at least two operands.

Core special forms are recognized by their spelling in list-head position.
They take precedence over callable bindings there; no core-name shadowing policy
has been finalized. Function values have strict Ruby lambda arity. Rest arguments
use `[x & xs]`, where `xs` is a Ruby Array. No implicit return or loop primitives.

`def` writes a single session's root environment, including when used inside a
function. Globals resolve at call time, permitting recursion and redefinition.
`set!` updates the nearest existing binding and errors for an unbound name.
`if` evaluates only its selected branch, with Ruby truth semantics. Missing else
and empty bodies return nil. `do` and function bodies return their last value.

`let` evaluates initializers sequentially. Each binding gets a new child frame:
an initializer sees earlier bindings and outer names; earlier closures cannot
see later bindings introduced by the same let. Duplicate names within one let
or parameter vector are rejected; nested shadowing works. Mutation changes the
shared captured binding. Destructuring is deferred.

Boron globals take precedence over uppercase Ruby constant lookup. If unbound,
an uppercase constant path resolves through Object and explicit nested constant
names. There is no implicit method lookup for a bare identifier.

## Ruby IR, emission, and execution

IR nodes model literals, locals, assignments, calls, arrays/hashes, sequences,
conditionals, and lambdas. Only the emitter constructs Ruby source strings.
Lowering builds typed IR; generated local names come from a compiler counter,
not user spellings. User strings and identifiers are emitted as escaped literals.

A small Environment helper implements binding lookup and mutation. Closures are
Ruby lambdas capturing these environments. This trades emission verbosity for
straightforward semantics while the language is young. More direct local-variable
lowering should follow measurements and semantic tests, not precede them.

`Compiler#compile` returns an expression program for execution with `boron_env`.
`standalone: true` adds a Boron require and fresh environment. Sessions compile and
execute through Ruby eval with a session environment. RubyVM is used only by a
test to verify syntax; the compiler itself does not require CRuby-specific APIs.

Strings are copied when emitted, so evaluating a literal again yields a fresh,
mutable String. Collection expressions also allocate fresh host collections.
Evaluation order follows Ruby's receiver/argument and array/hash element order.

## Ruby blocks and exceptions

`send-with-block` takes receiver, method Symbol, an argument Array, and a Proc.
Ordinary method sends do not reinterpret Proc arguments as blocks. Tests exercise
Array#map and File.open, including host-managed file closure.

Ruby exceptions retain their host classes. The CLI catches failures, prints a
concise diagnostic, and exits with status 1. Invalid CLI usage returns 2. Runtime
backtrace lines are generated Ruby positions; source maps are not implemented.
Boron binding errors include the original identifier location.

Explicit keyword/splat syntax, try/throw forms, classes, and a block surface macro
are future work. Hashes are not automatically converted to keyword arguments.

## Dependency research

Start with a handwritten recursive reader. S-expressions require no operator
precedence or statement grammar; direct construction gives us control over forms
and spans. Revisit when complexity warrants it.

| Option | Capability | Assessment for Boron |
| --- | --- | --- |
| [StringScanner](https://docs.ruby-lang.org/en/3.4/StringScanner.html) | Regex stream scanning with positions | Installed with this Ruby; reasonable if scanning becomes cumbersome. |
| [Parslet](https://kschiess.github.io/parslet/overview.html) | PEG rules and intermediate-tree transformations | First external parser candidate if a declarative grammar becomes useful. |
| [Racc](https://github.com/ruby/racc) | LALR(1) parser generation | Reconsider for a substantially more complex grammar. |

These are fit assessments, not benchmarks or Ruby 4 compatibility claims. Boron's
reader has no parsing dependency. StandardRB brings parser tooling transitively
for linting; that tooling is not used by the language implementation. Development
uses Minitest 5 and [StandardRB](https://github.com/standardrb/standard), locked with
Bundler. No test plugins or mocks. Formatting targets Ruby 3.2 syntax, matching
the implementation's use of Data. Lint exceptions are scoped to deliberate
generated-Ruby execution and interpolation-literal tests.

## Editor support

The declarative extension in `editors/vscode` provides a recursive TextMate
grammar and language configuration. Scopes distinguish callable heads, special
forms, Ruby sends, constants, Symbols, values, and identifiers. They do not attempt
binding resolution. Strings have no interpolation. The supplied harness exercises
VS Code's installed TextMate/Oniguruma engines without downloading npm packages.

## Development workflow

For each language slice: add focused failing Minitests, implement, then simplify
without changing behavior. Prefer observable semantics and errors over tests tied
to private helpers. Integration tests exercise execution and host behavior.
Keep the roadmap honest about partial milestones and deferred syntax.
