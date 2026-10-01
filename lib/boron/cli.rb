module Boron
  class CLI
    USAGE = <<~TEXT.freeze
      Usage:
        boron run FILE.bn [-- PROGRAM_ARGS...]
        boron compile [--emit-ruby] FILE.bn
        boron repl
        boron --help
    TEXT

    def self.run(arguments, input: $stdin, out: $stdout, err: $stderr)
      if arguments == ["repl"]
        require_relative "repl"
        return REPL.new(input: input, out: out, err: err).run
      end
      args = arguments.dup
      if args == ["--help"] || args == ["-h"]
        out.print USAGE
        return 0
      end
      command = args.shift
      args.shift if command == "compile" && args.first == "--emit-ruby"
      valid_arguments = args.length == 1 || (command == "run" && args.length >= 2 && args[1] == "--")
      unless ["run", "compile"].include?(command) && valid_arguments
        err.print USAGE
        return 2
      end
      path = args.first
      source = File.read(path, encoding: "UTF-8")
      sources = SourceRegistry.new
      sources.add(path, source)
      if command == "run"
        session = Session.new
        session.environment.define("ARGV", args.drop(2))
        session.evaluate(source, filename: path)
      else
        out.print Compiler.new.compile(source, filename: path, standalone: true)
      end
      0
    rescue ReadError, CompileError => error
      err.print DiagnosticRenderer.new(sources || SourceRegistry.new).render(error.diagnostic)
      1
    rescue UnboundName => error
      err.puts error.message
      1
    rescue StandardError, ScriptError => error
      err.puts "#{error.class}: #{error.message}"
      1
    end
  end
end
