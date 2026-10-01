require_relative "test_helper"
require "open3"
require "tempfile"
require "rbconfig"
require "json"

class JSONReportTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  REPORT = File.join(ROOT, "examples", "user_report.bn")

  def run_report(*args)
    Open3.capture3(RbConfig.ruby, File.join(ROOT, "bin", "boron"), "run", REPORT, "--", *args)
  end

  def with_json(source)
    Tempfile.create(["boron-users", ".json"]) do |file|
      file.write(source)
      file.flush
      yield file.path
    end
  end

  def test_report_filters_active_users_and_groups_roles
    source = JSON.generate([
      {name: "Ada", active: true, role: "admin"},
      {name: "Grace", active: false, role: "admin"},
      {name: "Linus", active: true, role: "developer"},
      {active: true}, {name: "Text flag", active: "true"}
    ])
    with_json(source) do |path|
      output, error, status = run_report(path)
      assert status.success?, error
      assert_empty error
      assert_equal({"total" => 5, "active" => 3, "names" => ["Ada", "Linus", "unnamed"],
        "by-role" => {"admin" => 1, "developer" => 1, "unknown" => 1}}, JSON.parse(output))
    end
  end

  def test_empty_input
    with_json("[]") do |path|
      output, error, status = run_report(path)
      assert status.success?, error
      assert_equal({"total" => 0, "active" => 0, "names" => [], "by-role" => {}}, JSON.parse(output))
    end
  end

  def test_help_usage_and_bad_input
    output, error, status = run_report("--help")
    assert status.success?, error
    assert_includes output, "Usage:"
    _, error, status = run_report
    refute status.success?
    assert_includes error, "Usage:"
    ["{}", "[1]", "not JSON"].each do |source|
      with_json(source) do |path|
        _, error, status = run_report(path)
        refute status.success?
        assert_match(/array of objects|JSON::ParserError/, error)
      end
    end
  end

  def test_compiled_report_receives_normal_ruby_program_arguments
    ruby = Boron::Compiler.new.compile(File.read(REPORT), standalone: true)
    with_json("[]") do |path|
      output, error, status = Open3.capture3(RbConfig.ruby, "-I#{ROOT}/lib", "-e", ruby, "--", path)
      assert status.success?, error
      assert_equal 0, JSON.parse(output).fetch("total")
    end
  end

  def test_run_arguments_do_not_include_interpreter_arguments
    Tempfile.create(["boron-args", ".bn"]) do |file|
      file.write('(require "json") (puts (.generate JSON ARGV))')
      file.flush
      output, error, status = Open3.capture3(RbConfig.ruby, File.join(ROOT, "bin", "boron"), "run", file.path, "--", "first", "--flag")
      assert status.success?, error
      assert_equal ["first", "--flag"], JSON.parse(output)
    end
  end
end
