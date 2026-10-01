module Boron
  class Reader
    INTEGER = /\A[+-]?\d+\z/
    FLOAT = /\A[+-]?(?:\d+\.\d+(?:[eE][+-]?\d+)?|\d+[eE][+-]?\d+)\z/
    WHITESPACE = [" ", "\t", "\r", "\n", "\f", "\v"].freeze
    DELIMITERS = ["(", ")", "[", "]", "{", "}", ";", "#", '"', "'", "`", "~"].freeze
    ESCAPES = {"n" => "\n", "r" => "\r", "t" => "\t", '"' => '"', "\\" => "\\"}.freeze

    def initialize(source, filename: "(string)")
      @characters = source.each_char.to_a
      @filename = filename.dup.freeze
      @offset = 0
      @line = 1
      @column = 1
    end

    def read_all
      forms = []
      skip_trivia
      until eof?
        forms << read_form
        skip_trivia
      end
      forms
    end

    private

    def read_form
      start = position
      case current
      when "(" then read_collection(start, ")", Form::List, "list")
      when "[" then read_collection(start, "]", Form::Vector, "vector")
      when "{" then read_collection(start, "}", Form::Map, "map")
      when "#"
        advance
        error("unsupported reader syntax", start) unless current == "{"
        read_collection(start, "}", Form::Set, "set")
      when ")", "]", "}"
        closer = current
        advance
        error("unexpected '#{closer}'", start)
      when '"' then read_string(start)
      when ":"
        advance
        name = scan_atom
        error("empty symbol literal", start) if name.empty?
        Syntax.new(name.to_sym, span_from(start))
      when "'", "`", "~"
        advance
        error("unsupported reader syntax", start)
      else
        read_atom(start)
      end
    end

    def read_collection(start, closer, type, label)
      advance
      opening_span = span_from(start)
      items = []
      loop do
        skip_trivia
        raise ReadError.new("unclosed #{label}", span: opening_span) if eof?
        if current == closer
          advance
          error("map requires an even number of forms", start) if type == Form::Map && items.length.odd?
          return Syntax.new(type.new(items), span_from(start))
        end
        items << read_form
      end
    end

    def read_string(start)
      advance
      value = +""
      until eof?
        character = current
        advance
        return Syntax.new(value.freeze, span_from(start)) if character == '"'
        if character == "\\"
          error("unclosed string", start) if eof?
          escaped = current
          advance
          error("unknown escape: \\#{escaped}", start) unless ESCAPES.key?(escaped)
          value << ESCAPES.fetch(escaped)
        else
          value << character
        end
      end
      error("unclosed string", start)
    end

    def read_atom(start)
      spelling = scan_atom
      datum = case spelling
      when "true" then true
      when "false" then false
      when "nil" then nil
      else
        if INTEGER.match?(spelling)
          Integer(spelling, 10)
        elsif FLOAT.match?(spelling)
          number = Float(spelling)
          error("float literal out of range", start) unless number.finite?
          number
        else
          Form::Identifier.new(spelling)
        end
      end
      Syntax.new(datum, span_from(start))
    end

    def scan_atom
      start_offset = @offset
      # Ruby's indexing messages are atoms despite containing vector delimiters.
      if @characters[@offset, 3]&.join == ".[]"
        3.times { advance }
        advance if current == "="
      else
        advance until eof? || WHITESPACE.include?(current) || DELIMITERS.include?(current)
      end
      @characters[start_offset...@offset].join
    end

    def skip_trivia
      loop do
        if WHITESPACE.include?(current)
          advance
        elsif current == ";"
          advance until eof? || current == "\n"
        else
          break
        end
      end
    end

    def current
      @characters[@offset]
    end

    def eof?
      @offset >= @characters.length
    end

    def advance
      if current == "\n"
        @line += 1
        @column = 1
      else
        @column += 1
      end
      @offset += 1
    end

    def position
      [@offset, @line, @column]
    end

    def span_from(start)
      SourceSpan.new(
        filename: @filename,
        start_offset: start[0], end_offset: @offset,
        start_line: start[1], start_column: start[2],
        end_line: @line, end_column: @column
      )
    end

    def error(message, start)
      raise ReadError.new(message, span: span_from(start))
    end
  end
end
