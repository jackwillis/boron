require_relative "test_helper"

class SequenceTest < Minitest::Test
  def evaluate(source)
    Boron::Session.new.evaluate(source)
  end

  def test_map_and_filter_work_with_ruby_enumerables
    assert_equal [2, 4, 6], evaluate("(map (fn [x] (* x 2)) (.new Range 1 3))")
    assert_equal [2, 3], evaluate("(filter (fn [x] (> x 1)) (.each [1 2 3]))")
    assert_equal [:a, :b], evaluate("(map (fn [entry] (get entry 0)) {:a 1 :b 2})")
    assert_equal [0, 1], evaluate("(filter (fn [x] x) [false nil 0 1])")
  end

  def test_reduce_group_by_and_count
    assert_equal 16, evaluate("(reduce + 10 [1 2 3])")
    assert_equal 10, evaluate("(reduce + 10 [])")
    assert_equal({1 => [1, 3], 0 => [2, 4]}, evaluate("(group-by (fn [x] (% x 2)) [1 2 3 4])"))
    assert_equal 3, evaluate("(count (.new Range 1 3))")
    assert_equal 0, evaluate("(count [])")
  end

  def test_helpers_are_shadowable_and_do_not_mutate_input
    assert_equal [[2, 4], [1, 2]], evaluate("(let [xs [1 2]] [(map (fn [x] (* x 2)) xs) xs])")
    assert_equal :local, evaluate("(let [map (fn [f xs] :local)] (map nil []))")
    assert_raises(ArgumentError) { evaluate("(reduce + [])") }
  end
end
