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
    first[0] << "b"
    assert_equal ["ab"], first
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
end
