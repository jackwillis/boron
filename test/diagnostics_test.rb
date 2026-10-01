require_relative "test_helper"
require "boron/cli"
require "stringio"
require "tempfile"

class DiagnosticsTest < Minitest::Test
  def test_reader_and_compile_errors_carry_structured_diagnostics
    error = assert_raises(Boron::ReadError) { Boron::Reader.new("[", filename: "bad.bn").read_all }
    assert_equal :reader, error.diagnostic.kind
    assert_equal "unclosed vector", error.diagnostic.message
    assert_equal error.span, error.diagnostic.primary_span
    error = assert_raises(Boron::CompileError) { Boron::Compiler.new.compile("(let [x 1 x 2] x)") }
    assert_equal :compile, error.diagnostic.kind
    assert_equal 2, error.diagnostic.labels.length
    assert_match(/duplicate let binding/, error.message)
  end

  def test_renderer_uses_snapshot_unicode_crlf_and_multiple_labels
    sources = Boron::SourceRegistry.new
    source = +"(let [é 1\r\n      é 2] é)"
    sources.add("unicode.bn", source)
    error = assert_raises(Boron::CompileError) { Boron::Compiler.new.compile(source, filename: "unicode.bn") }
    rendered = Boron::DiagnosticRenderer.new(sources).render(error.diagnostic)
    assert_includes rendered, "unicode.bn:2:7:"
    assert_includes rendered, "1 | (let [é 1"
    assert_includes rendered, "2 |       é 2] é)"
    assert_includes rendered, "first bound here"
    assert_includes rendered, "^"
    refute_includes rendered, "\r"
    source.replace("changed")
    assert_includes Boron::DiagnosticRenderer.new(sources).render(error.diagnostic), "é 2"
  end

  def test_renderer_handles_eof_multiline_and_missing_source
    sources = Boron::SourceRegistry.new
    sources.add("empty.bn", "")
    span = Boron::SourceSpan.new("empty.bn", 0, 0, 1, 1, 1, 1)
    diagnostic = Boron::Diagnostic.new(kind: :compile, message: "failed", primary_span: span)
    assert_includes Boron::DiagnosticRenderer.new(sources).render(diagnostic), "^"
    missing = Boron::DiagnosticRenderer.new(Boron::SourceRegistry.new).render(diagnostic)
    assert_includes missing, "empty.bn:1:1:"
    sources.add("empty.bn", "a\nb")
    span = Boron::SourceSpan.new("empty.bn", 0, 3, 1, 1, 2, 2)
    diagnostic = Boron::Diagnostic.new(kind: :compile, message: "failed", primary_span: span)
    assert_includes Boron::DiagnosticRenderer.new(sources).render(diagnostic), "continues through line 2"
  end

  def test_cli_renders_excerpt_without_changing_library_exceptions
    Tempfile.create(["diagnostic", ".bn"]) do |file|
      file.write("(.upcase)\n")
      file.flush
      err = StringIO.new
      assert_equal 1, Boron::CLI.run(["run", file.path], err: err)
      assert_includes err.string, "1 | (.upcase)"
      assert_includes err.string, "method send requires a receiver"
    end
    assert_raises(ZeroDivisionError) { Boron::Session.new.evaluate("(/ 1 0)") }
  end
end
