require_relative "test_helper"

class ReaderTest < Minitest::Test
  def read(source, filename: "test.bn")
    Boron::Reader.new(source, filename: filename).read_all
  end

  def datum(syntax)
    value = syntax.datum
    case value
    when Boron::Form::List then value.items.map { |item| datum(item) }
    when Boron::Form::Identifier then [:identifier, value.name]
    else value
    end
  end

  def test_reads_nested_arithmetic_without_evaluating
    forms = read("(+ 1 (* 2 3))")
    assert_equal 1, forms.length
    assert_equal [[:identifier, "+"], 1, [[:identifier, "*"], 2, 3]], datum(forms.first)
  end

  def test_reads_multiple_top_level_forms_and_empty_lists
    assert_equal [[], 42, [[:identifier, "hello"]]], read("() 42 (hello)").map { |form| datum(form) }
  end

  def test_empty_input_and_comments
    assert_empty read("")
    assert_empty read(" \t\r\n; only a comment")
    assert_equal [1, 2], read("; before\n1 ; between\n2; at EOF").map(&:datum)
  end

  def test_signed_integers_and_decimal_floats
    assert_equal [0, 12, -12, 12, 1.5, -0.25, 200.0, 0.002],
      read("0 12 -12 +12 1.5 -0.25 2e2 2.0e-3").map(&:datum)
  end

  def test_identifiers_are_distinct_from_ruby_symbols
    names = %w[+ - active? set! make-adder Foo::Bar .upcase &]
    forms = read(names.join(" "))
    assert_equal names, forms.map { |form| form.datum.name }
    forms.each { |form| assert_instance_of Boron::Form::Identifier, form.datum }
  end

  def test_locations_cover_whole_list_and_individual_atoms
    form = read("; intro\n (+ 12\n  x)", filename: "example.bn").first
    span = form.span
    assert_equal "example.bn", span.filename
    assert_equal [2, 2, 3, 5, 9, 19],
      [span.start_line, span.start_column, span.end_line, span.end_column, span.start_offset, span.end_offset]
    atom_span = form.datum.items.last.span
    assert_equal [3, 3, 3, 4],
      [atom_span.start_line, atom_span.start_column, atom_span.end_line, atom_span.end_column]
  end

  def test_unicode_offsets_count_characters
    forms = read("α β")
    assert_equal "α", forms.first.datum.name
    assert_equal [2, 3], [forms.last.span.start_offset, forms.last.span.start_column]
  end

  def test_unexpected_closing_parenthesis_has_location
    error = assert_raises(Boron::ReadError) { read("\n )") }
    assert_match(/test\.bn:2:2: unexpected '\)'/, error.message)
    assert_equal [2, 2], [error.span.start_line, error.span.start_column]
  end

  def test_unclosed_list_points_to_its_opening_parenthesis
    error = assert_raises(Boron::ReadError) { read("(a\n (b") }
    assert_match(/test\.bn:2:2: unclosed list/, error.message)
  end

  def test_quotation_prefixes_desugar_with_source_spans
    {"'" => "quote", "`" => "quasiquote", "~" => "unquote", "~@" => "unquote-splicing"}.each do |prefix, name|
      form = read("#{prefix}a").first
      assert_equal [[:identifier, name], [:identifier, "a"]], datum(form)
      assert_equal [1, 1], [form.span.start_line, form.span.start_column]
      assert_raises(Boron::ReadError) { read(prefix) }
    end
  end

  def test_literal_values_and_collections
    forms = read('true false nil :name "Ada" [1 (+ 2 3)] {:name "Ada"} #{:a :b}')
    assert_equal [true, false, nil, :name, "Ada"], forms.first(5).map(&:datum)
    assert_instance_of Boron::Form::Vector, forms[5].datum
    assert_equal [1, [[:identifier, "+"], 2, 3]], forms[5].datum.items.map { |item| datum(item) }
    assert_instance_of Boron::Form::Map, forms[6].datum
    assert_equal [:name, "Ada"], forms[6].datum.items.map(&:datum)
    assert_instance_of Boron::Form::Set, forms[7].datum
  end

  def test_strings_escape_without_ruby_interpolation
    assert_equal "line\n\t\r\"\\", read('"line\n\t\r\"\\\\"').first.datum
    assert_equal "\#{dangerous}", read('"#{dangerous}"').first.datum # standard:disable Lint/InterpolationCheck
  end

  def test_delimited_reader_errors
    {"[1)" => /unexpected '\)'/, "{1}" => /even number/, "[1" => /unclosed vector/,
     '"abc' => /unclosed string/, '"\q"' => /unknown escape/, ":" => /empty symbol/,
     "#x" => /unsupported reader syntax/, "}" => /unexpected/}.each do |source, message|
      error = assert_raises(Boron::ReadError, source) { read(source) }
      assert_match message, error.message
    end
  end

  def test_bracket_method_identifier
    assert_equal ".[]", read("(.[] [1] 0)").first.datum.items.first.datum.name
  end
end
