require_relative "test_helper"
require "open3"
require "tempfile"
require "rbconfig"

class CLITest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  EXE = File.join(ROOT, "exe", "boron")

  def cli(*arguments)
    Open3.capture3(RbConfig.ruby, EXE, *arguments)
  end

  def program(source)
    Tempfile.create(["boron-test", ".bn"]) do |file|
      file.write(source)
      file.flush
      yield file.path
    end
  end

  def test_run_executes_the_program
    program("(puts (+ 1 (* 2 3)))") do |path|
      stdout, stderr, status = cli("run", path)
      assert status.success?, stderr
      assert_equal "7\n", stdout
      assert_empty stderr
    end
  end

  def test_compile_emits_runnable_ruby_without_executing_boron
    program('(puts (.upcase "hello"))') do |path|
      ruby, stderr, status = cli("compile", "--emit-ruby", path)
      assert status.success?, stderr
      assert_match(/public_send/, ruby)
      assert_empty stderr
      output, error, result = Open3.capture3(RbConfig.ruby, "-I#{ROOT}/lib", "-e", ruby)
      assert result.success?, error
      assert_equal "HELLO\n", output
      assert_empty error
    end
  end

  def test_error_exit_codes_and_diagnostics
    program("\n(if)") do |path|
      output, error, result = cli("run", path)
      assert_equal 1, result.exitstatus
      assert_empty output
      assert_includes error, "#{path}:2:1:"
    end
    program("(/ 1 0)") do |path|
      _, error, result = cli("run", path)
      assert_equal 1, result.exitstatus
      assert_includes error, "ZeroDivisionError"
    end
    _, error, result = cli("run", "/tmp/boron-nonexistent-input-file.bn")
    assert_equal 1, result.exitstatus
    assert_includes error, "No such file"
  end

  def test_usage_and_help
    _, error, result = cli("unknown")
    assert_equal 2, result.exitstatus
    assert_includes error, "Usage:"
    output, error, result = cli("--help")
    assert result.success?, error
    assert_includes output, "compile"
  end
end
