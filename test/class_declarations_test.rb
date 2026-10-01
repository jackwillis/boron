require_relative "test_helper"

class ClassDeclarationsTest < Minitest::Test
  def setup
    @session = Boron::Session.new
  end

  def teardown
    Object.send(:remove_const, :BoronDeclarationExample) if Object.const_defined?(:BoronDeclarationExample, false)
  end

  def evaluate(source)
    @session.evaluate(source, filename: "classes.bn")
  end

  def test_named_modules_and_classes_are_real_ruby_values
    namespace = evaluate("(defmodule BoronDeclarationExample)")
    assert_instance_of Module, namespace
    assert_equal "BoronDeclarationExample", namespace.name
    klass = evaluate("(defclass BoronDeclarationExample::User)")
    assert_instance_of Class, klass
    assert_equal Object, klass.superclass
    assert_equal "BoronDeclarationExample::User", klass.name
    assert_instance_of klass, evaluate("(.new BoronDeclarationExample::User)")
    assert_same klass, Boron::Session.new.evaluate("BoronDeclarationExample::User")
  end

  def test_inheritance_expression_is_evaluated_once
    klass = evaluate(<<~BN)
      (defmodule BoronDeclarationExample)
      (def calls 0)
      (defclass BoronDeclarationExample::Items <
        (do (set! calls (+ calls 1)) Array))
    BN
    assert_equal Array, klass.superclass
    assert_equal 1, evaluate("calls")
    assert_equal [], evaluate("(.to_a (.new BoronDeclarationExample::Items))")
  end

  def test_existing_declarations_are_reused_without_replacing_constants
    namespace = evaluate("(defmodule BoronDeclarationExample)")
    assert_same namespace, evaluate("(defmodule BoronDeclarationExample)")
    klass = evaluate("(defclass BoronDeclarationExample::Items < Array)")
    assert_same klass, evaluate("(defclass BoronDeclarationExample::Items)")
    assert_same klass, evaluate("(defclass BoronDeclarationExample::Items < Array)")
    assert_raises(TypeError) { evaluate("(defclass BoronDeclarationExample::Items < Hash)") }
    assert_raises(TypeError) { evaluate("(defmodule BoronDeclarationExample::Items)") }
    assert_raises(TypeError) { evaluate("(defclass BoronDeclarationExample)") }
    assert_raises(TypeError) { evaluate("(defclass BoronDeclarationExample::Bad < 42)") }
    assert_same klass, namespace.const_get(:Items, false)
  end

  def test_invalid_declaration_syntax_has_call_site_context
    ["(defmodule lowercase)", '(defmodule "Name")', "(defclass Foo::)", "(defclass Foo Array)",
      "(defclass Foo <)", "(defclass Foo < Object extra)", "(defmodule Foo extra)"].each do |source|
      error = assert_raises(Boron::CompileError, source) { evaluate(source) }
      assert_match(/classes\.bn:1:/, error.message)
    end
  end

  def test_missing_namespace_is_not_created_and_inherited_constants_are_not_reused
    assert_raises(NameError) { evaluate("(defclass BoronDeclarationExample::User)") }
    evaluate("(defmodule BoronDeclarationExample) (defclass BoronDeclarationExample::Parent)")
    BoronDeclarationExample::Parent.const_set(:Child, Class.new)
    evaluate("(defclass BoronDeclarationExample::Derived < BoronDeclarationExample::Parent)")
    own = evaluate("(defclass BoronDeclarationExample::Derived::Child)")
    refute_same BoronDeclarationExample::Parent::Child, own
    assert BoronDeclarationExample::Derived.const_defined?(:Child, false)
  end

  def test_declarations_expand_and_compile_as_macros
    form = evaluate("(macroexpand '(defclass BoronDeclarationExample < Array))")
    assert_equal ".declare_class", form.items.first.name
    source = "(defmodule BoronDeclarationExample) (defclass BoronDeclarationExample::User)"
    ruby = Boron::Compiler.new.compile(source, standalone: true)
    klass = Kernel.eval(ruby) # standard:disable Security/Eval
    assert_equal "BoronDeclarationExample::User", klass.name
  end
end
