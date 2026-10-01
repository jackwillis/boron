require_relative "test_helper"
require "boron/cli"
require "stringio"
require "open3"

class StringLiteralsTest < Minitest::Test
  def evaluate(source)
    Boron::Session.new.evaluate(source)
  end

  def test_literals_are_frozen_in_values_and_quotation
    ['"Ada"', "'\"Ada\"", '`("Ada")'].each do |source|
      value = evaluate(source)
      value = value.items.first if value.is_a?(Boron::Form::List)
      assert_equal "Ada", value
      assert value.frozen?, source
      assert_raises(FrozenError) { value << "!" }
    end
    assert evaluate('["Ada"]').first.frozen?
    assert evaluate('{:name "Ada"}').fetch(:name).frozen?
  end

  def test_explicit_duplicates_are_fresh_mutable_values
    session = Boron::Session.new
    session.evaluate('(def make (fn [] (.dup "Ada")))')
    first = session.evaluate("(make)")
    first << "!"
    second = session.evaluate("(make)")
    assert_equal "Ada!", first
    assert_equal "Ada", second
    refute second.frozen?
    refute_same first, second
  end

  def test_host_strings_keep_their_own_mutability
    constructed = evaluate('(.new String "Ada")')
    refute constructed.frozen?
    constructed << "!"
    assert_equal "Ada!", constructed
    result = evaluate('(+ "a" "b")')
    refute result.frozen?
    assert_equal "ab", result
  end

  def test_emitted_code_has_frozen_literals_and_only_explicit_dup_calls
    compiler = Boron::Compiler.new
    ruby = compiler.compile('"Ada"', standalone: true)
    refute_includes ruby, ".dup"
    assert Kernel.eval(ruby).frozen? # standard:disable Security/Eval
    explicit = compiler.compile('(.dup "Ada")', standalone: true)
    assert_includes explicit, ":dup"
    refute Kernel.eval(explicit).frozen? # standard:disable Security/Eval
    refute_includes compiler.compile("(let [x 1] x)"), ".dup"
  end

  def test_repl_reports_frozen_mutation_and_allows_explicit_copy
    out = StringIO.new
    err = StringIO.new
    input = StringIO.new('(def name "Ada")' + "\n" + '(.concat name "!")' + "\n" + '(.concat (.dup name) "!")' + "\n")
    assert_equal 0, Boron::CLI.run(["repl"], input: input, out: out, err: err)
    assert_includes err.string, "FrozenError"
    assert_equal "\"Ada\"\n\"Ada!\"\n", out.string
  end

  def test_literal_truth_conditions_do_not_emit_ruby_warnings
    source = '(if "yes" (puts "ok") (puts "wrong"))'
    ruby = Boron::Compiler.new.compile(source, standalone: true)
    output, error, status = Open3.capture3(RbConfig.ruby, "-I#{File.expand_path("../lib", __dir__)}", "-e", ruby)
    assert status.success?, error
    assert_equal "ok\n", output
    assert_empty error
  end
end
