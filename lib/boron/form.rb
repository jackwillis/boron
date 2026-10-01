module Boron
  SourceSpan = Data.define(
    :filename, :start_offset, :end_offset,
    :start_line, :start_column, :end_line, :end_column
  )

  Syntax = Data.define(:datum, :span)

  module Form
    Identifier = Data.define(:name) do
      def initialize(name:)
        super(name: name.dup.freeze)
      end
    end

    Collection = Data.define(:items) do
      def initialize(items:)
        super(items: items.dup.freeze)
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
