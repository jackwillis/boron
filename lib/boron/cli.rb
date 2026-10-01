module Boron
  class CLI
    USAGE = <<~TEXT.freeze
      Usage:
        boron run FILE.bn
        boron compile [--emit-ruby] FILE.bn
        boron --help
    TEXT

    def self.run(arguments, out: $stdout, err: $stderr)
      args = arguments.dup
      if args == ["--help"] || args == ["-h"]
        out.print USAGE
        return 0
      end
      command = args.shift
      args.shift if command == "compile" && args.first == "--emit-ruby"
      unless ["run", "compile"].include?(command) && args.length == 1
        err.print USAGE
        return 2
      end
      path = args.first
      source = File.read(path, encoding: "UTF-8")
      if command == "run"
        Session.new.evaluate(source, filename: path)
      else
        out.print Compiler.new.compile(source, filename: path, standalone: true)
      end
      0
    rescue ReadError, CompileError, UnboundName => error
      err.puts error.message
      1
    rescue StandardError, ScriptError => error
      err.puts "#{error.class}: #{error.message}"
      1
    end
  end
end
