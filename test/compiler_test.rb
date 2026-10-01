require_relative "test_helper"
require "tempfile"

class CompilerTest < Minitest::Test
  def evaluate(source)
    Boron::Session.new.evaluate(source, filename: "test.bn")
  end

  def test_arithmetic_and_host_semantics
    assert_equal 7, evaluate("(+ 1 (* 2 3))")
    assert_equal 2, evaluate("(/ 5 2)")
    assert_equal "ab", evaluate('(+ "a" "b")')
    assert_equal 0, evaluate("(+)")
    assert_equal 1, evaluate("(*)")
    assert_equal(-3, evaluate("(- 3)"))
  end

  def test_collections_evaluate_their_members
    assert_equal [1, 5, true, false, nil, :name], evaluate("[1 (+ 2 3) true false nil :name]")
    assert_equal({"ab" => 3, :name => "Ada"}, evaluate('{(+ "a" "b") (+ 1 2) :name "Ada"}'))
    assert_equal ::Set[1, 2], evaluate("\#{1 1 (+ 1 1)}")
    first = evaluate('["a"]')
    assert_raises(FrozenError) { first[0] << "b" }
    first << "b"
    assert_equal ["a", "b"], first
    assert_equal ["a"], evaluate('["a"]')
  end

  def test_empty_program_and_sequence_result
    assert_nil evaluate("")
    assert_equal 3, evaluate("1 2 3")
    assert_equal 3, evaluate("(do 1 2 3)")
    assert_nil evaluate("(do)")
  end

  def test_ir_and_emitted_ruby_are_inspectable
    compiler = Boron::Compiler.new
    ir = compiler.lower("(+ 1 2)")
    assert_instance_of Boron::RubyIR::Sequence, ir
    ruby = compiler.compile("(+ 1 2)")
    assert_match(/\.call\(1, 2\)/, ruby)
    RubyVM::InstructionSequence.compile(ruby)
  end

  def test_generated_strings_do_not_execute_interpolation
    assert_equal "\#{raise \"oops\"}", evaluate('"#{raise \"oops\"}"') # standard:disable Lint/InterpolationCheck
  end

  def test_ruby_truth_and_lazy_branches
    assert_equal :yes, evaluate("(if 0 :yes missing)")
    assert_equal :yes, evaluate('(if "" :yes missing)')
    assert_equal :no, evaluate("(if false missing :no)")
    assert_equal :no, evaluate("(if nil missing :no)")
    assert_nil evaluate("(if false 1)")
  end

  def test_lexical_scope_sequential_bindings_and_shadowing
    assert_equal 5, evaluate("(let [x 2 y (+ x 1)] (+ x y))")
    assert_equal [10, 20, 10], evaluate("(def x 10) [x (let [x 20] x) x]")
    assert_equal 9, evaluate("(let [+ (fn [a b] 9)] (+ 1 2))")
    assert_raises(Boron::UnboundName) { evaluate("(let [x 2] x) x") }
    assert_equal 10, evaluate("(def x 10) (let [f (fn [] x) x 20] (f))")
    assert_equal 10, evaluate("(def x 10) (let [x (+ x 1) f (fn [] x)] (set! x 10) (f))")
  end

  def test_closures_and_first_class_calls
    assert_equal 25, evaluate("((fn [x] (* x x)) 5)")
    assert_equal 7, evaluate(<<~BN)
      (def make-adder (fn [x] (fn [y] (+ x y))))
      (def add2 (make-adder 2))
      (add2 5)
    BN
    assert_equal 64, evaluate("(def square (fn [x] (* x x))) (square 8)")
    assert_equal [2, 3], evaluate("((fn [x & xs] xs) 1 2 3)")
    assert_raises(ArgumentError) { evaluate("((fn [x] x))") }
  end

  def test_recursive_global_function_and_session_persistence
    session = Boron::Session.new
    session.evaluate("(def fact (fn [n] (if (<= n 1) 1 (* n (fact (- n 1))))))")
    assert_equal 120, session.evaluate("(fact 5)")
    assert_equal 720, session.evaluate("(fact 6)")
  end

  def test_assignment_mutates_the_captured_binding
    assert_equal [1, 2], evaluate(<<~BN)
      (def counter (let [n 0] (fn [] (set! n (+ n 1)))))
      [(counter) (counter)]
    BN
    assert_raises(Boron::UnboundName) { evaluate("(set! missing 1)") }
  end

  def test_ruby_sends_and_constants
    assert_equal "HELLO", evaluate('(.upcase "hello")')
    assert_equal 2, evaluate("(.[] [1 2 3] 1)")
    assert_equal [1, 2], evaluate("(let [xs [1]] (.push xs 2) xs)")
    assert_equal "xxx", evaluate('(.new String "xxx")')
    assert_equal String, evaluate("String")
    assert_equal "HELLO", evaluate('(send "hello" :upcase)')
    assert_equal '{"hello":"world"}', evaluate('(require "json") (.generate JSON {:hello "world"})')
  end

  def test_function_call_is_not_implicit_method_dispatch
    assert_raises(Boron::UnboundName) { evaluate('(upcase "hello")') }
    assert_raises(NoMethodError) { evaluate('(.puts Object "hello")') }
    assert_raises(ZeroDivisionError) { evaluate("(/ 1 0)") }
  end

  def test_blocks_are_explicit_and_proc_arguments_remain_arguments
    assert_equal [2, 4, 6], evaluate("(send-with-block [1 2 3] :map [] (fn [x] (* x 2)))")
    assert_raises(ArgumentError) { evaluate("(.map [1 2] (fn [x] x))") }
    Tempfile.create("boron-block") do |file|
      file.write("Ruby file contents")
      file.flush
      session = Boron::Session.new
      session.environment.define("path", file.path)
      assert_equal "Ruby file contents", session.evaluate(<<~BN)
        (def handle nil)
        (send-with-block File :open [path "r"]
          (fn [file] (set! handle file) (.read file)))
      BN
      assert session.evaluate("(.closed? handle)")
    end
  end

  def test_compile_errors_have_source_locations
    ["()", "(if)", "(def 1 2)", "(let [x] x)", "(let [x 1 x 2] x)",
      "(fn [x x] x)", "(fn [x &] x)", "(.upcase)", "(set! 1 2)"].each do |source|
      error = assert_raises(Boron::CompileError, source) { evaluate(source) }
      assert_match(/test\.bn:1:\d+:/, error.message)
    end
    error = assert_raises(Boron::UnboundName) { evaluate("\nmissing") }
    assert_match(/test\.bn:2:1/, error.message)
  end

  def test_get_preserves_ruby_indexing_semantics
    assert_equal 20, evaluate("(get [10 20] 1)")
    assert_equal 20, evaluate("(get [10 20] -1)")
    assert_nil evaluate("(get [10] 2)")
    assert_equal false, evaluate("(get {:present false} :present)")
    assert_equal 7, evaluate("(get {:present 7} :present)")
    assert_nil evaluate("(get {:present 7} :missing)")
  end

  def test_not_uses_ruby_truth
    %w[false nil].each { |value| assert_equal true, evaluate("(not #{value})") }
    ["true", "0", '""', "[]", "{}"].each { |value| assert_equal false, evaluate("(not #{value})") }
  end

  def test_comparisons_check_every_adjacent_pair
    {"=" => ["2 2 2", "2 2 3"], "==" => ["2 2 2", "2 2 3"],
     "!=" => ["1 2 1", "1 2 2"], "<" => ["1 2 3", "1 2 2"],
     "<=" => ["1 2 2", "1 2 1"], ">" => ["3 2 1", "3 2 2"],
     ">=" => ["3 2 2", "3 2 3"]}.each do |operator, (passing, failing)|
      assert_equal true, evaluate("(#{operator} #{passing})"), operator
      assert_equal false, evaluate("(#{operator} #{failing})"), operator
      assert_raises(ArgumentError) { evaluate("(#{operator} 1)") }
    end
  end

  def test_remaining_arithmetic_builtins_and_arity
    assert_equal 5, evaluate("(- 10 3 2)")
    assert_equal 2, evaluate("(/ 20 2 5)")
    assert_equal 2, evaluate("(% 8 3)")
    ["(-)", "(/ 1)", "(% 1)", "(% 1 2 3)"].each do |source|
      assert_raises(ArgumentError) { evaluate(source) }
    end
  end

  def test_def_inside_a_function_writes_and_redefines_session_globals
    session = Boron::Session.new
    assert_equal 7, session.evaluate("((fn [] (let [local 7] (def exported local))))")
    assert_equal 7, session.evaluate("exported")
    assert_equal 9, session.evaluate("(let [exported 100] (def exported 9))")
    assert_equal 9, session.evaluate("exported")
  end

  def test_sessions_do_not_share_globals_or_builtin_redefinitions
    first = Boron::Session.new
    second = Boron::Session.new
    first.evaluate("(def private-value 10) (def + (fn [a b] 99))")
    assert_raises(Boron::UnboundName) { second.evaluate("private-value") }
    assert_equal 3, second.evaluate("(+ 1 2)")
    second.evaluate("(def private-value 20)")
    assert_equal 10, first.evaluate("private-value")
    assert_equal 20, second.evaluate("private-value")
    assert_equal 99, first.evaluate("(+ 1 2)")
  end

  def test_assignment_updates_the_nearest_binding_and_shared_closures
    assert_equal [[3, 3], 1], evaluate(<<~BN)
      (def x 1)
      [(let [x 2
             write (fn [] (set! x 3))
             read (fn [] x)]
         [(write) (read)]) x]
    BN
  end

  def test_calls_sends_and_collections_evaluate_once_in_source_order
    sources = [
      "(do ((do (mark :callee) +) (mark 1) (mark 2)) events)",
      "(do (.push (do (mark :receiver) []) (mark 1) (mark 2)) events)",
      "(do [(mark 1) (mark 2) (mark 3)] events)",
      "(do {(mark 1) (mark 2) (mark 3) (mark 4)} events)",
      '(do #{(mark 1) (mark 1) (mark 2)} events)'
    ]
    expected = [[:callee, 1, 2], [:receiver, 1, 2], [1, 2, 3], [1, 2, 3, 4], [1, 1, 2]]
    sources.zip(expected).each do |source, order|
      assert_equal order, evaluate(<<~BN + source)
        (def events [])
        (def mark (fn [value] (.push events value) value))
      BN
    end
  end

  def test_file_block_closes_the_handle_when_the_body_raises
    Tempfile.create("boron-block-error") do |file|
      session = Boron::Session.new
      session.environment.define("path", file.path)
      assert_raises(ZeroDivisionError) do
        session.evaluate(<<~BN)
          (def handle nil)
          (send-with-block File :open [path "r"]
            (fn [file] (set! handle file) (/ 1 0)))
        BN
      end
      assert session.evaluate("(.closed? handle)")
      assert_equal 3, session.evaluate("(+ 1 2)")
    end
  end

  def test_empty_bodies_rest_only_parameters_and_excess_arguments
    assert_nil evaluate("(let [])")
    assert_nil evaluate("(let [x 1])")
    assert_nil evaluate("((fn []))")
    assert_equal [], evaluate("((fn [& xs] xs))")
    assert_equal [1, 2], evaluate("((fn [& xs] xs) 1 2)")
    assert_equal [], evaluate("((fn [x & xs] xs) 1)")
    assert_raises(ArgumentError) { evaluate("((fn [x] x) 1 2)") }
    assert_raises(ArgumentError) { evaluate("((fn [x & xs] xs))") }
  end

  def test_false_and_nil_bindings_shadow_parent_values_and_constants
    assert_equal [false, nil], evaluate("(def x 1) [(let [x false] x) (let [x nil] x)]")
    assert_equal false, evaluate("(let [String false] String)")
    assert_equal Encoding::UTF_8, evaluate("Encoding::UTF_8")
    assert_raises(NameError) { evaluate("Boron::MissingConstantForTest") }
  end

  def test_collections_are_fresh_and_duplicate_keys_use_the_last_value
    session = Boron::Session.new
    session.evaluate('(def make (fn [] [[1] {:x [2]} #{3} (.dup "a")]))') # standard:disable Lint/InterpolationCheck
    first = session.evaluate("(make)")
    first[0] << 9
    first[1][:x] << 9
    first[2].add(9)
    first[3] << "b"
    assert_equal [[1], {x: [2]}, ::Set[3], "a"], session.evaluate("(make)")
    assert_equal({x: 2}, evaluate("(let [key :x] {key 1 key 2})"))
  end

  def test_malformed_special_forms_fail_before_execution
    ["(if true 1 2 3)", "(def x)", "(def x 1 2)", "(set! x)",
      "(let)", "(let 1 2)", "(fn)", "(fn 1 2)", "(fn [x & xs y] x)",
      "(fn [& &] 1)", "(fn [x & x] x)", "(def .bad 1)",
      "(let [Foo::Bar 1] 1)", "(. 1)"].each do |source|
      session = Boron::Session.new
      error = assert_raises(Boron::CompileError, source) do
        session.evaluate("(def touched true)\n#{source}", filename: "invalid.bn")
      end
      assert_match(/invalid\.bn:2:\d+:/, error.message)
      assert_raises(Boron::UnboundName) { session.evaluate("touched") }
    end
  end
end
