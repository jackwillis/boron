require_relative "test_helper"

class RubyEmitterTest < Minitest::Test
  IR = Boron::RubyIR

  def execute(node)
    # Execute generated expressions to verify the emitted Ruby semantics.
    Kernel.eval(Boron::RubyEmitter.new.emit(node)) # standard:disable Security/Eval
  end

  def test_sequence_and_conditionals_are_expressions
    node = IR::Conditional.new(
      IR::Literal.new(false), IR::Local.new("missing"),
      IR::Sequence.new([IR::Literal.new(1), IR::Literal.new(2)])
    )
    assert_equal 2, execute(node)
  end

  def test_nested_call_and_lambda_receiver
    body = IR::Call.new(IR::Local.new("x"), :*, [IR::Literal.new(2)])
    function = IR::Lambda.new(["x"], nil, body)
    assert_equal 6, execute(IR::Call.new(function, :call, [IR::Literal.new(3)]))
  end

  def test_literal_emission_handles_escaping_and_unicode
    values = ["quotes: \"\\\n", "\#{raise \"oops\"}", "λ", :"odd symbol", nil, false]
    values.each do |value|
      actual = execute(IR::Literal.new(value))
      value.nil? ? assert_nil(actual) : assert_equal(value, actual)
    end
  end
end
