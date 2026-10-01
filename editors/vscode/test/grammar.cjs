// Use the TextMate and Oniguruma engines shipped with VS Code: no npm install.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const extensionRoot = path.resolve(__dirname, '..');
const manifest = JSON.parse(fs.readFileSync(path.join(extensionRoot, 'package.json'), 'utf8'));
const grammarSource = fs.readFileSync(path.join(extensionRoot, 'syntaxes/boron.tmLanguage.json'), 'utf8');
const modulesRoot = process.env.BORON_VSCODE_MODULES || path.join(path.dirname(process.execPath), 'resources/app/node_modules.asar');
const textmate = require(path.join(modulesRoot, 'vscode-textmate'));
const oniguruma = require(path.join(modulesRoot, 'vscode-oniguruma'));

async function main() {
  const wasm = fs.readFileSync(path.join(modulesRoot, 'vscode-oniguruma/release/onig.wasm'));
  await oniguruma.loadWASM(wasm.buffer.slice(wasm.byteOffset, wasm.byteOffset + wasm.byteLength));
  const registry = new textmate.Registry({
    onigLib: Promise.resolve({
      createOnigScanner: patterns => new oniguruma.OnigScanner(patterns),
      createOnigString: source => new oniguruma.OnigString(source)
    }),
    loadGrammar: async scope => scope === 'source.boron'
      ? textmate.parseRawGrammar(grammarSource, 'boron.tmLanguage.json') : null
  });
  const grammar = await registry.loadGrammar('source.boron');
  let assertions = 0;
  function scopesAt(source, needle, occurrence = 0) {
    let offset = -1;
    for (let i = 0; i <= occurrence; i++) offset = source.indexOf(needle, offset + 1);
    assert(offset >= 0, `missing fixture token ${needle}`);
    const prefix = source.slice(0, offset);
    const row = prefix.split('\n').length - 1;
    const column = offset - (prefix.lastIndexOf('\n') + 1);
    let state = textmate.INITIAL;
    for (const [index, line] of source.split('\n').entries()) {
      const result = grammar.tokenizeLine(line, state);
      state = result.ruleStack;
      if (index === row) return result.tokens.find(token => token.startIndex <= column && token.endIndex > column).scopes;
    }
    throw new Error('token not found');
  }
  function has(source, needle, scope, occurrence = 0) {
    const scopes = scopesAt(source, needle, occurrence);
    assert(scopes.includes(scope), `${JSON.stringify(needle)} expected ${scope}; got ${scopes.join(', ')}`);
    assertions++;
  }
  function lacks(source, needle, scope) {
    assert(!scopesAt(source, needle).includes(scope), `${needle} incorrectly has ${scope}`);
    assertions++;
  }

  has('(def square (fn [x] (* x x)))', 'def', 'keyword.control.boron');
  has('(def square 1)', 'square', 'variable.other.definition.boron');
  has('(let [if 1] if)', 'if', 'variable.other.boron');
  has('(definitely 1)', 'definitely', 'entity.name.function.boron');
  has('(if true false nil)', 'true', 'constant.language.boolean.boron');
  has('(if true false nil)', 'nil', 'constant.language.nil.boron');
  has('(+ -12 2.5e-3)', '+', 'keyword.operator.boron');
  has('(+ -12 2.5e-3)', '-12', 'constant.numeric.boron');
  has('(+ -12 2.5e-3)', '2.5e-3', 'constant.numeric.boron');
  has('123abc', '123abc', 'variable.other.boron');
  has('foo123', 'foo123', 'variable.other.boron');
  has('{:name "Ada"}', ':name', 'constant.other.symbol.boron');
  has('(.generate JSON {:hello "world"})', '.generate', 'entity.name.function.member.boron');
  has('(.generate JSON {:hello "world"})', 'JSON', 'support.class.boron');
  has('Sinatra::Base', 'Sinatra::Base', 'support.class.boron');
  has('(.[] xs 0)', '.[]', 'entity.name.function.member.boron');
  has('(.[]= xs 0 1)', '.[]=', 'entity.name.function.member.boron');
  has('(.get App "/" & (fn [] "hello"))', '&', 'keyword.operator.rest.boron');
  has('(defmacro twice [x] `(+ ~x ~x))', 'defmacro', 'keyword.control.boron');
  has('(when true 1)', 'when', 'keyword.control.boron');
  lacks('(.[] xs 0)', '[', 'punctuation.section.brackets.begin.boron');
  has('(fn [x & xs] xs)', '&', 'keyword.operator.rest.boron');
  has('(puts "hello") ; comment (fake)', '; comment', 'comment.line.semicolon.boron');
  has('"; (if :name) #{missing}"', ';', 'string.quoted.double.boron');
  lacks('"#{missing}"', 'missing', 'variable.other.boron');
  has('"line\\n"', '\\n', 'constant.character.escape.boron');
  has('"bad\\q"', '\\q', 'invalid.illegal.escape.boron');
  has('"first\n; still string\nlast"\n(def x 1)', ';', 'string.quoted.double.boron');
  has('"first\n; still string\nlast"\n(def x 1)', 'def', 'keyword.control.boron');
  has('#{:ruby :lisp}', '#{', 'punctuation.section.set.begin.boron');
  has('[{:x (f 1)}]', '1', 'constant.numeric.boron');
  has('(\n  ; head follows\n  if true 1 2)', 'if', 'keyword.control.boron');
  has('`(x ~y ~@zs)', '~@', 'punctuation.definition.quote.boron');
  assert.equal(manifest.contributes.grammars[0].scopeName, 'source.boron');
  assert(manifest.contributes.languages[0].extensions.includes('.bn'));
  assert(manifest.contributes.grammars[0].unbalancedBracketScopes.includes('entity.name.function.member.boron'));
  const configuration = JSON.parse(fs.readFileSync(path.join(extensionRoot, 'language-configuration.json'), 'utf8'));
  const word = new RegExp(configuration.wordPattern, 'g');
  assert.deepEqual('make-adder active? set! Sinatra::Base .[]'.match(word), ['make-adder', 'active?', 'set!', 'Sinatra::Base', '.[]']);
  assert(!configuration.autoClosingPairs.some(pair => pair.open === "'" || pair.open === '`'));
  for (const file of fs.readdirSync(path.resolve(extensionRoot, '../../examples')).filter(file => file.endsWith('.bn'))) {
    const source = fs.readFileSync(path.resolve(extensionRoot, '../../examples', file), 'utf8');
    let state = textmate.INITIAL;
    for (const line of source.split('\n')) state = grammar.tokenizeLine(line, state).ruleStack;
    assert.equal(state.depth, textmate.INITIAL.depth, `${file} ends inside an unclosed grammar scope`);
  }
  registry.dispose();
  console.log(`TextMate grammar: ${assertions} scope assertions and extension checks passed`);
}
main().catch(error => { console.error(error); process.exitCode = 1; });
