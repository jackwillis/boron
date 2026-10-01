require_relative "test_helper"
require "boron/cli"
require "stringio"

class REPLTest < Minitest::Test
  def run_repl(source)
    out = StringIO.new
    err = StringIO.new
    status = Boron::CLI.run(["repl"], input: StringIO.new(source), out: out, err: err)
    [out.string, err.string, status]
  end

  def test_persistent_bindings_macros_and_multiline_input
    output, error, status = run_repl("(def x 2)\n(+ x\n 3)\n(defmacro answer [] 42)\n(answer)\n:quit\n")
    assert_equal "2\n5\nnil\n42\n", output
    assert_empty error
    assert_equal 0, status
  end

  def test_errors_recover_and_macroexpand_is_readable
    output, error, status = run_repl("(if)\n(/ 1 0)\n(macroexpand '(when true 3))\n(+ 1 2)\n")
    assert_includes error, "(repl:1):1:1:"
    assert_includes error, "ZeroDivisionError"
    assert_equal "(if true (do 3) nil)\n3\n", output
    assert_equal 0, status
  end

  def test_eof_incomplete_input_is_reported_without_execution
    output, error, status = run_repl("(def x 1\n")
    assert_empty output
    assert_includes error, "unclosed list"
    assert_equal 1, status
  end

  def test_commands_comments_and_multiline_strings
    output, error, status = run_repl("; comment\n:help\n\"first\nsecond\"\n:exit\nmissing\n")
    assert_includes output, ":quit"
    assert_includes output, '"first\nsecond"'
    assert_empty error
    assert_equal 0, status
  end

  def test_unexpected_closers_do_not_wait_for_more_input
    output, error, = run_repl(")\n42\n")
    assert_includes error, "unexpected ')'"
    assert_equal "42\n", output
  end
end
