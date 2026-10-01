require_relative "test_helper"

class ExplicitBlockSendTest < Minitest::Test
  def evaluate(source)
    Boron::Session.new.evaluate(source, filename: "blocks.bn")
  end

  def test_dynamic_block_send_primitive_remains_available
    assert_equal [2, 4], evaluate("(send-with-block [1 2] :map [] (fn [x] (* x 2)))")
  end

  def test_ruby_block_conversion_and_indexing
    assert_equal ["ADA"], evaluate('(.map ["Ada"] & :upcase)')
    assert_equal [1, 2], evaluate("(.to_a [1 2] & nil)")
    assert_equal 1, evaluate("(.[] {:a 1} :a & nil)")
  end

  def test_evaluation_order_and_ordinary_proc_arguments
    assert_equal [1, 2, 3], evaluate(<<~BN)
      (def order [])
      (.reduce (do (.push order 1) [10])
        (do (.push order 2) 0)
        & (do (.push order 3) (fn [sum x] (+ sum x))))
      order
    BN
    assert_instance_of Proc, evaluate("(get (.push [] (fn [] 1)) 0)")
  end

  def test_call_site_block_marker
    assert_equal [2, 4], evaluate("(.map [1 2] & (fn [x] (* x 2)))")
    assert_equal 13, evaluate("(.reduce [1 2] 10 & (fn [sum x] (+ sum x)))")
    assert_equal ["ADA"], evaluate("(.map [\"Ada\"] & :upcase)")
    assert_equal ["&"], evaluate('(.push [] "&")')
    ["(.map [1] &)", "(.reduce [1] & (fn [x] x) 0)", "(.map [1] & &)"].each do |source|
      assert_raises(Boron::CompileError) { evaluate(source) }
    end
  end

  def test_missing_receiver_or_block_is_a_compile_error
    ["(.map)", "(.map & (fn [x] x))", "(. [] & (fn [] 1))"].each do |source|
      error = assert_raises(Boron::CompileError) { evaluate(source) }
      assert_match(/blocks\.bn:1:/, error.message)
    end
  end

  def test_emitted_ruby_preserves_block_send
    ruby = Boron::Compiler.new.compile("(.map [1 2] & (fn [x] (+ x 1)))", standalone: true)
    assert_equal [2, 3], Kernel.eval(ruby) # standard:disable Security/Eval
  end
end
