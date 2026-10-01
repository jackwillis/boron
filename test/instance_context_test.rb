require_relative "test_helper"

class InstanceContextTest < Minitest::Test
  def evaluate(source)
    Boron::Session.new.evaluate(source)
  end

  def test_ivar_helpers_use_real_ruby_instance_variables
    source = <<~BN
      (let [receiver (.new Object)]
        [(ivar-defined? receiver :user)
         (ivar-get receiver :user)
         (ivar-set! receiver :user "Ada")
         (.instance_variable_get receiver :@user)
         (ivar-defined? receiver "@user")
         (ivar-get receiver "user")])
    BN
    assert_equal [false, nil, "Ada", "Ada", true, "Ada"], evaluate(source)
    ruby = Boron::Compiler.new.compile(source, standalone: true)
    assert_equal [false, nil, "Ada", "Ada", true, "Ada"], Kernel.eval(ruby) # standard:disable Security/Eval
    assert_raises(NameError) { evaluate('(ivar-get (.new Object) "bad-name")') }
    assert_raises(TypeError) { evaluate("(ivar-get (.new Object) 1)") }
  end

  def test_instance_exec_supplies_explicit_receiver_and_preserves_lexical_capture
    assert_equal 12, evaluate(<<~BN)
      (let [receiver (.new Object) captured 7]
        (.instance_exec receiver 5 &
          (with-self (fn [self x] (if (= self receiver) (+ captured x) 0)))))
    BN
  end

  def test_define_method_uses_actual_instance_and_strict_function_arity
    assert_equal true, evaluate(<<~BN)
      (def klass (.new Class))
      (.define_method klass :matches &
        (with-self (fn [self other] (= self other))))
      (def instance (.new klass))
      (.matches instance instance)
    BN
    assert_raises(ArgumentError) do
      evaluate("(.instance_exec (.new Object) & (with-self (fn [self x] x)))")
    end
  end

  def test_wrappers_are_first_class_and_compile
    source = "(.instance_exec \"Ada\" & (with-self (fn [self] (.upcase self))))"
    assert_equal "ADA", evaluate(source)
    ruby = Boron::Compiler.new.compile(source, standalone: true)
    assert_equal "ADA", Kernel.eval(ruby) # standard:disable Security/Eval
    assert_raises(TypeError) { evaluate("(with-self 1)") }
    assert_equal ["first", "second"], evaluate(<<~BN)
      (let [callback (with-self (fn [self] self))]
        [(.instance_exec "first" & callback) (.instance_exec "second" & callback)])
    BN
  end
end
