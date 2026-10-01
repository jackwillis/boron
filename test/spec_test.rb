require_relative "test_helper"
require "boron/spec"
require "stringio"

class SpecTest < Minitest::Test
  def run_spec(source, filter: nil)
    output = StringIO.new
    runner = Boron::Spec::Runner.new(out: output, filter: filter)
    runner.load(source, filename: "example_spec.bn")
    [runner.run, output.string]
  end

  def test_implicit_fixtures_share_real_ivars_and_keep_explicit_hash
    status, output = run_spec(<<~BN)
      (let [name "Ada"]
        (describe "fixtures"
          (before [s]
            (assert (.is_a? s Hash))
            (put s :legacy 12)
            (set-fixture! :user name)
            (ivar-set! self :nullable nil))
          (after [] (assert (= (fixture :user) "Grace")))
          (it "mixes APIs" [s]
            (assert (= (get s :legacy) 12))
            (assert (= (ivar-get self :user) "Ada"))
            (assert (ivar-defined? self :nullable))
            (assert (= (fixture :nullable) nil))
            (assert (= (set-fixture! :user "Grace") "Grace")))))
    BN
    assert_equal 0, status, output
  end

  def test_implicit_fixtures_are_fresh_and_missing_fixtures_raise
    status, output = run_spec(<<~BN)
      (def previous nil)
      (describe "fresh"
        (before []
          (refute (= self previous))
          (set! previous self)
          (refute (ivar-defined? self :user)))
        (it "first" [] (set-fixture! :user 12))
        (it "second" [] (assert-raises KeyError (fixture :user))))
    BN
    assert_equal 0, status, output
  end

  def test_implicit_fixtures_survive_setup_failure_through_teardown
    status, output = run_spec(<<~BN)
      (describe "cleanup"
        (before []
          (set-fixture! :resource "open")
          (.raise Kernel RuntimeError "setup"))
        (after [] (assert (= (fixture :resource) "open")))
        (it "unused" [] (assert false)))
    BN
    assert_equal 1, status
    assert_includes output, "1 tests, 1 assertions, 0 failures, 1 errors"
  end

  def test_fixture_helpers_are_lexical_and_runner_local
    status, output = run_spec(<<~BN)
      (it "captures context" []
        (set-fixture! :user "Ada")
        (let [read (fn [] (fixture :user))]
          (assert (= (read) "Ada"))))
    BN
    assert_equal 0, status, output
    ["(fixture :user)", "(set-fixture! :user 1)"].each do |source|
      assert_raises(Boron::UnboundName) { Boron::Session.new.evaluate(source) }
    end
  end

  def test_computed_assertion_head
    status, = run_spec('(it "computed" [] (assert ((fn [a b] (.== a b)) 1 1)))')
    assert_equal 0, status
  end

  def test_invalid_fixture_parameters
    ["[a b]", "[& args]", "[self]", "s"].each do |parameters|
      ['it "bad"', "before", "after"].each do |declaration|
        assert_raises(Boron::CompileError) { run_spec("(#{declaration} #{parameters} true)") }
      end
    end
  end

  def test_conditional_and_macro_generated_locations
    status, output = run_spec(<<~BN)
      (defmacro generated [] '(it "generated" [] (assert false)))
      (if false (it "skipped" [] true))
      (generated)
      (it "literal" [] (assert false))
    BN
    assert_equal 1, status
    assert_includes output, "example_spec.bn:3:1"
    assert_includes output, "example_spec.bn:4:1"
  end

  def test_hook_order
    status, = run_spec(<<~BN)
      (def calls [])
      (describe "outer"
        (before [] (.push calls :outer))
        (after [] (.push calls :outer-after))
        (context "inner"
          (before [] (.push calls :inner))
          (after [] (.push calls :first-after))
          (after [] (.push calls :second-after))
          (it "body" [] (.push calls :body))))
      (it "order" [] (assert (= calls [:outer :inner :body :second-after :first-after :outer-after])))
    BN
    assert_equal 0, status
  end

  def test_macros_are_runner_local
    assert_raises(Boron::UnboundName) { Boron::Session.new.evaluate('(it "outside" [] true)') }
  end

  def test_nested_hooks_and_fresh_fixtures
    status, output = run_spec(<<~BN)
      (describe "cart"
        (before [s] (put s :items []))
        (after [s] (assert (= (count (get s :items)) 1)))
        (context "coffee"
          (before [s] (.push (get s :items) 12))
          (it "first" [s] (assert (= (get (get s :items) 0) 12)))
          (it "second" [s] (assert (= (count (get s :items)) 1)))))
    BN
    assert_equal 0, status
    assert_includes output, "2 tests, 4 assertions, 0 failures, 0 errors"
  end

  def test_assertion_operands_are_evaluated_once_and_local_equality_is_respected
    status, output = run_spec(<<~BN)
      (it "once" []
        (let [calls [] = (fn [a b] true)]
          (assert (= (do (.push calls 1) 10) (do (.push calls 2) 12)))
          (assert (.== calls [1 2]))))
    BN
    assert_equal 0, status
    assert_includes output, "2 assertions"
  end

  def test_failures_errors_and_teardown_continue
    status, output = run_spec(<<~BN)
      (describe "suite"
        (after [] (assert true))
        (it "bad equality" [] (assert (= (+ 2 3) 12)))
        (it "error" [] (/ 1 0))
        (it "refute" [] (refute false))
        (it "raises" [] (assert-raises ZeroDivisionError (/ 1 0))))
    BN
    assert_equal 1, status
    assert_includes output, "(= (+ 2 3) 12)"
    assert_includes output, "actual: 5"
    assert_includes output, "expected: 12"
    assert_includes output, "example_spec.bn:3:"
    assert_includes output, "4 tests, 7 assertions, 1 failures, 1 errors"
  end

  def test_wrong_exception_is_an_assertion_failure
    status, output = run_spec('(it "wrong" [] (assert-raises ArgumentError (/ 1 0)))')
    assert_equal 1, status
    assert_includes output, "expected ArgumentError, got ZeroDivisionError"
    assert_includes output, "1 failures, 0 errors"
  end

  def test_filter_and_missing_expected_exception
    status, output = run_spec('(it "skip" [] (assert false)) (it "chosen" [] (assert-raises RuntimeError 42))', filter: "chosen")
    assert_equal 1, status
    assert_includes output, "1 tests, 1 assertions, 1 failures, 0 errors"
    assert_includes output, "expected RuntimeError"
  end

  def test_teardowns_all_run_even_when_setup_or_teardown_fails
    status, output = run_spec(<<~BN)
      (describe "outer"
        (after [] (assert true))
        (context "inner"
          (before [] (.raise Kernel RuntimeError "setup"))
          (after [] (.raise Kernel RuntimeError "cleanup"))
          (it "never runs" [] (assert false))))
    BN
    assert_equal 1, status
    assert_includes output, "1 tests, 1 assertions, 0 failures, 2 errors"
  end
end
