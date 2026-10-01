module Boron
  SourceSpan = Data.define(
    :filename, :start_offset, :end_offset,
    :start_line, :start_column, :end_line, :end_column
  )

  MacroOrigin = Data.define(:name, :call_span)

  Syntax = Data.define(:datum, :span, :origin) do
    def initialize(datum:, span:, origin: nil)
      super
    end
  end

  module Form
    Identifier = Data.define(:name) do
      def initialize(name:)
        super(name: name.dup.freeze)
      end

      def binding_key
        name
      end
    end

    GeneratedIdentifier = Class.new(Identifier) do
      def binding_key
        self
      end
    end

    Collection = Data.define(:items) do
      include Enumerable

      def initialize(items:)
        super(items: items.dup.freeze)
      end

      def each(&block)
        return enum_for(:each) unless block
        items.each(&block)
        self
      end
    end

    List = Class.new(Collection)
    Vector = Class.new(Collection)
    Map = Class.new(Collection)
    Set = Class.new(Collection)
  end

  class ReadError < StandardError
    attr_reader :span

    def initialize(message, span:)
      @span = span
      super("#{span.filename}:#{span.start_line}:#{span.start_column}: #{message}")
    end
  end
end
