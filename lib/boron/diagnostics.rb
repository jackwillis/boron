module Boron
  Label = Data.define(:span, :message)

  Diagnostic = Data.define(:kind, :message, :primary_span, :labels, :notes, :help, :cause) do
    def initialize(kind:, message:, primary_span:, labels: [], notes: [], help: nil, cause: nil)
      super(kind: kind, message: message.dup.freeze, primary_span: primary_span,
            labels: labels.dup.freeze, notes: notes.map { |note| note.dup.freeze }.freeze,
            help: help&.dup&.freeze, cause: cause)
    end

    def summary
      span = primary_span
      "#{span.filename}:#{span.start_line}:#{span.start_column}: #{message}"
    end
  end

  class DiagnosticError < StandardError
    attr_reader :diagnostic

    def initialize(message, span:, kind:, labels: [], notes: [], help: nil)
      @diagnostic = Diagnostic.new(kind: kind, message: message, primary_span: span,
        labels: labels, notes: notes, help: help)
      super(@diagnostic.summary)
    end

    def span
      diagnostic.primary_span
    end
  end

  class SourceRegistry
    def initialize
      @sources = {}
    end

    def add(filename, source)
      @sources[filename.dup.freeze] = source.dup.freeze
    end

    def line(filename, number)
      source = @sources[filename]
      return "" if source == "" && number == 1
      source&.split("\n", -1)&.[](number - 1)&.delete_suffix("\r")
    end
  end

  class DiagnosticRenderer
    def initialize(sources)
      @sources = sources
    end

    def render(diagnostic)
      result = ["error: #{diagnostic.message}"]
      result.concat(excerpt(diagnostic.primary_span))
      diagnostic.labels.each { |label| result.concat(excerpt(label.span, label.message)) }
      diagnostic.notes.each { |note| result << " = #{note}" }
      result << " help: #{diagnostic.help}" if diagnostic.help
      result.join("\n") + "\n"
    end

    private

    def excerpt(span, message = nil)
      result = [" --> #{span.filename}:#{span.start_line}:#{span.start_column}:"]
      line = @sources.line(span.filename, span.start_line)
      return result unless line
      width = span.start_line.to_s.length
      prefix = line[0, span.start_column - 1].to_s.gsub(/[^\t]/, " ")
      length = if span.end_line == span.start_line
        [span.end_column - span.start_column, 1].max
      else
        [line.length - span.start_column + 2, 1].max
      end
      length = length.clamp(1, [line.length - span.start_column + 2, 1].max)
      result << "#{span.start_line} | #{line}"
      marker = "#{" " * width} | #{prefix}#{"^" * length}"
      marker += " #{message}" if message
      result << marker
      result << " = span continues through line #{span.end_line}" if span.end_line > span.start_line
      result
    end
  end
end
