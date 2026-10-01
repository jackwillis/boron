require_relative "test_helper"
require "boron/cli"
require "stringio"
require "open3"

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

  def test_actual_cli_has_no_prompts_when_piped_and_handles_cyclic_values
    input = "(def x 3)\n(+ x 4)\n(def cycle [])\n(.push cycle cycle)\n"
    output, error, status = Open3.capture3(RbConfig.ruby, File.expand_path("../bin/boron", __dir__), "repl", stdin_data: input)
    assert status.success?, error
    assert_empty error
    assert_equal "3\n7\n[]\n[#<cycle>]\n", output
  end

  def test_interactive_prompts_and_interrupt_clear_partial_input
    input = StringIO.new("(\n42\n:quit\n")
    def input.tty?
      true
    end

    def input.gets
      @calls = (@calls || 0) + 1
      raise Interrupt if @calls == 2
      super
    end
    out = StringIO.new
    err = StringIO.new
    assert_equal 0, Boron::CLI.run(["repl"], input: input, out: out, err: err)
    assert_includes out.string, "...> "
    assert_includes out.string, "42\n"
    assert_equal "^C\n", err.string
  end
end
