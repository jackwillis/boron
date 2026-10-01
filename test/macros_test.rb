require_relative "test_helper"

class MacrosTest < Minitest::Test
  def evaluate(source)
    Boron::Session.new.evaluate(source, filename: "macros.bn")
  end

  def test_macro_location_is_the_current_call_site
    session = Boron::Session.new
    session.evaluate("(defmacro where [] (macro-location))", filename: "definitions.bn")
    assert_equal "calls.bn:2:1", session.evaluate("\n(where)", filename: "calls.bn")
    assert_equal "next.bn:1:1", session.evaluate("(where)", filename: "next.bn")
    assert_raises(Boron::UnboundName) { session.evaluate("(macro-location)") }
  end

  def test_quote_distinguishes_identifiers_lists_and_host_collections
    value = evaluate("'(missing :name [x] {:a 1} \#{1 2})")
    assert_instance_of Boron::Form::List, value
    assert_instance_of Boron::Form::Identifier, value.items[0]
    assert_equal "missing", value.items[0].name
    assert_equal :name, value.items[1]
    assert_instance_of Boron::Form::Vector, value.items[2]
    assert_equal "x", value.items[2].items[0].name
    assert_instance_of Boron::Form::Map, value.items[3]
    assert_equal [:a, 1], value.items[3].items
    assert_instance_of Boron::Form::Set, value.items[4]
    assert_equal [1, 2], value.items[4].items
    assert_equal [], evaluate("'()").items
  end

  def test_quasiquote_unquote_and_splice
    value = evaluate("(let [x 2 xs [3 4]] `(1 ~x ~@xs 5))")
    assert_equal [1, 2, 3, 4, 5], value.items
    assert_equal [1, 2, 3], evaluate("(let [xs [2 3]] `[1 ~@xs])").items
    assert_equal [1, 2], evaluate("`(~@'(1 2))").items
    nested = evaluate("(let [x 2] `(outer `(inner ~x) ~x))")
    assert_equal 2, nested.items.last
    assert_equal "quasiquote", nested.items[1].items[0].name
    assert_equal "unquote", nested.items[1].items[1].items[1].items[0].name
  end

  def test_user_macros_expand_before_execution_and_are_variadic
    assert_equal 7, evaluate(<<~BN)
      (defmacro twice [expression] `(+ ~expression ~expression))
      (twice 3.5)
    BN
    assert_equal 3, evaluate(<<~BN)
      (defmacro sequence [& body] `(do ~@body))
      (sequence 1 2 3)
    BN
    assert_equal 5, evaluate(<<~BN)
      (defmacro identity [form] form)
      (identity (let [x 5] x))
    BN
  end

  def test_standard_macros_are_macros_and_preserve_branching
    assert_equal 64, evaluate("(defn square [x] (* x x)) (square 8)")
    assert_equal 3, evaluate("(when true 1 2 3)")
    assert_nil evaluate("(when false missing)")
    assert_equal 4, evaluate("(unless false 4)")
    assert_nil evaluate("(unless true missing)")
    assert_equal 1, evaluate("(def x 0) (when (do (set! x (+ x 1)) true) x)")
  end

  def test_macroexpand_is_inspectable_and_does_not_execute_expansion
    value = evaluate("(macroexpand '(when true missing))")
    assert_equal "if", value.items.first.name
    assert_equal "do", value.items[2].items.first.name
    assert_equal "missing", value.items[2].items[1].name
    assert_equal "if", evaluate("'(if true 1 2)").items.first.name
  end

  def test_macros_persist_in_a_session_but_are_not_shared
    session = Boron::Session.new
    session.evaluate("(defmacro answer [] 42)")
    assert_equal 42, session.evaluate("(answer)")
    assert_raises(Boron::UnboundName) { Boron::Session.new.evaluate("(answer)") }
  end

  def test_gensym_prevents_accidental_binding_capture
    assert_equal 11, evaluate(<<~BN)
      (defmacro plus-one [expression]
        (let [temporary (gensym)]
          `(let [~temporary 1] (+ ~temporary ~expression))))
      (let [temporary 10] (plus-one temporary))
    BN
    symbols = evaluate("[(gensym) (gensym)]")
    refute_equal symbols[0], symbols[1]
    assert_equal 11, evaluate(<<~BN)
      (defmacro same-spelling []
        (let [generated (gensym "collision")
              ordinary (.new Boron::Form::Identifier (.name generated))]
          `(let [~ordinary 10 ~generated 1] (+ ~ordinary ~generated))))
      (same-spelling)
    BN
  end

  def test_macro_errors_include_call_site_and_bound_expansion
    error = assert_raises(Boron::CompileError) { evaluate("(defmacro fail [x] (/ 1 0))\n(fail 2)") }
    assert_match(/macros\.bn:2:1.*fail.*ZeroDivisionError/, error.message)
    assert_raises(Boron::CompileError) { evaluate("(defmacro forever [] '(forever)) (forever)") }
    ["~x", "~@xs", "`~@xs", "(defmacro bad)", "(quote 1 2)"].each do |source|
      assert_raises(Boron::CompileError, source) { evaluate(source) }
    end
    assert_raises(TypeError) { evaluate("`(~@1)") }
  end

  def test_inserted_input_forms_keep_their_source_location
    error = assert_raises(Boron::UnboundName) { evaluate("(defmacro identity [x] x)\n(identity missing)") }
    assert_match(/macros\.bn:2:11:/, error.message)
  end

  def test_phase_separation_generated_locations_and_output_validation
    assert_raises(Boron::CompileError) { evaluate("(def x 42) (defmacro answer [] x) (answer)") }
    assert_raises(Boron::CompileError) { evaluate("(defmacro invalid [] [1 2]) (invalid)") }
    error = assert_raises(Boron::UnboundName) { evaluate("(defmacro generated [] 'missing)\n(generated)") }
    assert_match(/macros\.bn:2:1:/, error.message)
    source = "(defmacro answer [] 42) (answer)"
    ruby = Boron::Compiler.new.compile(source, standalone: true)
    assert_equal 42, Kernel.eval(ruby) # standard:disable Security/Eval
    refute_includes ruby, "defmacro"
  end
end
