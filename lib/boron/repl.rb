require_relative "../boron"

module Boron
  class REPL
    HELP = "Enter Boron forms; multiline input is supported. :quit/:exit leave; :help shows this message.\n".freeze

    def initialize(input: $stdin, out: $stdout, err: $stderr)
      @input = input
      @out = out
      @err = err
      @session = Session.new
      @session.environment.define("ARGV", [])
    end

    def run
      buffer = +""
      number = 1
      pending = nil
      loop do
        @out.print(buffer.empty? ? "boron> " : "...> ") if @input.tty?
        @out.flush
        begin
          line = @input.gets
        rescue Interrupt
          buffer.clear
          pending = nil
          @err.puts "^C"
          next
        end
        unless line
          return 0 if buffer.empty?
          render(pending)
          return 1
        end
        if buffer.empty?
          return 0 if [":quit", ":exit"].include?(line.strip)
          if line.strip == ":help"
            @out.print HELP
            next
          end
        end
        buffer << line
        filename = "(repl:#{number})"
        @session.sources.add(filename, buffer)
        begin
          forms = Reader.new(buffer, filename: filename).read_all
          if forms.empty?
            buffer.clear
            next
          end
          value = @session.evaluate(buffer, filename: filename)
          @out.puts Printer.format(value)
        rescue IncompleteInput => error
          pending = error
          next
        rescue DiagnosticError => error
          render(error)
        rescue StandardError, ScriptError => error
          @err.puts "#{error.class}: #{error.message}"
        rescue Interrupt
          @err.puts "^C"
        end
        buffer.clear
        pending = nil
        number += 1
      end
    end

    private

    def render(error)
      @err.print DiagnosticRenderer.new(@session.sources).render(error.diagnostic)
    end
  end
end
