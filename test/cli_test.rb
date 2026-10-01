require_relative "test_helper"
require "open3"
require "tempfile"
require "rbconfig"

class CLITest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  EXE = File.join(ROOT, "bin", "boron")

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

  def test_spec_status_filtering_and_no_matches
    program('(it "passing" [] (assert true)) (it "failing" [] (assert false))') do |path|
      output, error, result = cli("test", path)
      assert_equal 1, result.exitstatus
      assert_empty error
      assert_includes output, "FAIL: failing"
      output, error, result = cli("test", path, "--filter", "passing")
      assert_equal 0, result.exitstatus
      assert_empty error
      assert_includes output, "1 tests, 1 assertions, 0 failures, 0 errors"
      output, error, result = cli("test", path, "--filter", "absent")
      assert_equal 1, result.exitstatus
      assert_empty error
      assert_includes output, "No tests matched."
    end
  end

  def test_spec_argument_validation_and_load_errors
    [["test"], ["test", "file", "--filter"], ["test", "file", "--wrong", "value"],
      ["test", "file", "extra"]].each do |arguments|
      output, error, result = cli(*arguments)
      assert_equal 2, result.exitstatus
      assert_empty output
      assert_includes error, "Usage:"
    end
    {"(if)" => "(if)", "[1" => "unclosed vector", "missing" => "unbound identifier",
     "(/ 1 0)" => "ZeroDivisionError"}.each do |source, diagnostic|
      program(source) do |path|
        output, error, result = cli("test", path)
        assert_equal 1, result.exitstatus
        assert_empty output
        assert_includes error, diagnostic
      end
    end
    _, error, result = cli("test", "/tmp/boron-nonexistent-input-file.bn")
    assert_equal 1, result.exitstatus
    assert_includes error, "No such file"
    program("") do |path|
      output, _, result = cli("test", path)
      assert_equal 1, result.exitstatus
      assert_includes output, "No tests matched."
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

  def test_reader_binding_and_library_errors_have_failure_status
    {"[1" => "unclosed vector", "missing" => "unbound identifier missing",
     '(require "boron_missing_library_for_test")' => "LoadError"}.each do |source, diagnostic|
      program(source) do |path|
        output, error, result = cli("run", path)
        assert_equal 1, result.exitstatus
        assert_empty output
        assert_includes error, diagnostic
      end
    end
  end

  def test_compile_without_flag_does_not_execute_side_effects
    program('(puts "should only appear when run")') do |path|
      ruby, error, result = cli("compile", path)
      assert result.success?, error
      assert_empty error
      assert_includes ruby, 'require "boron"'
      assert ruby.start_with?("# frozen_string_literal: true\n")
      output, stderr, status = cli("run", path)
      assert status.success?, stderr
      assert_equal "should only appear when run\n", output
    end
  end

  def test_invalid_argument_counts_and_short_help
    [[], ["run"], ["compile"], ["run", "a", "b"], ["compile", "--emit-ruby"]].each do |arguments|
      output, error, result = cli(*arguments)
      assert_equal 2, result.exitstatus
      assert_empty output
      assert_includes error, "Usage:"
    end
    output, error, result = cli("-h")
    assert result.success?, error
    assert_empty error
    assert_includes output, "Usage:"
  end
end
