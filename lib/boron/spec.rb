require "boron"

module Boron
  module Spec
    class Failure < StandardError; end

    class ExampleContext
      def fixture(name)
        variable = Runtime.ivar_name(name)
        unless instance_variable_defined?(variable)
          raise KeyError, "undefined fixture #{name.inspect}"
        end
        instance_variable_get(variable)
      end

      def set_fixture(name, value)
        instance_variable_set(Runtime.ivar_name(name), value)
      end
    end

    Group = Struct.new(:name, :parent, :before, :after)
    Example = Struct.new(:name, :group, :body, :location)

    class Runner
      def initialize(out: $stdout, filter: nil)
        @out = out
        @filter = filter
        @root = Group.new(name: nil, parent: nil, before: [], after: [])
        @group = @root
        @examples = []
        @assertions = 0
        @session = Session.new
        {"describe" => :describe, "it" => :example, "before" => :before_hook,
         "after" => :after_hook, "assert" => :assertion, "raises" => :raises}.each do |name, method|
          @session.environment.define("boron-spec-#{name}", self.method(method))
        end
        path = File.join(__dir__, "spec.bn")
        @session.evaluate(File.read(path), filename: path)
      end

      def sources
        @session.sources
      end

      def load(source, filename:)
        @session.evaluate(source, filename: filename)
      end

      def describe(name, body)
        previous = @group
        @group = Group.new(name: name, parent: previous, before: [], after: [])
        body.call
      ensure
        @group = previous
      end

      def example(name, body, location)
        @examples << Example.new(name: name, group: @group, body: body, location: location)
      end

      def before_hook(body)
        @group.before << body
      end

      def after_hook(body)
        @group.after << body
      end

      def assertion(value, expression, operands)
        @assertions += 1
        return true if value
        message = Printer.format(expression)
        if operands
          message += "\n  actual: #{Printer.format(operands[0])}\n  expected: #{Printer.format(operands[1])}"
        end
        raise Failure, message
      end

      def raises(type, body)
        unless type.is_a?(Class) && type <= Exception
          raise ArgumentError, "assert-raises requires an exception class"
        end
        @assertions += 1
        begin
          body.call
        rescue StandardError, ScriptError => error
          return error if error.is_a?(type)
          raise Failure, "expected #{type}, got #{error.class}: #{error.message}"
        end
        raise Failure, "expected #{type}, but nothing was raised"
      end

      def run
        selected = @examples.select { |test| !@filter || full_name(test).include?(@filter) }
        failures = 0
        errors = 0
        selected.each do |test|
          problems = execute(test)
          if problems.empty?
            @out.puts "PASS: #{full_name(test)}"
          else
            problems.each do |error|
              failure = error.is_a?(Failure)
              failure ? failures += 1 : errors += 1
              @out.puts "#{failure ? "FAIL" : "ERROR"}: #{full_name(test)}"
              @out.puts "  #{test.location}" if test.location
              @out.puts "  #{error.class}: #{error.message}"
            end
          end
        end
        @out.puts "#{selected.length} tests, #{@assertions} assertions, #{failures} failures, #{errors} errors"
        if selected.empty?
          @out.puts "No tests matched."
          return 1
        end
        (failures + errors).zero? ? 0 : 1
      end

      private

      def groups(test)
        chain = []
        group = test.group
        while group
          chain.unshift(group)
          group = group.parent
        end
        chain
      end

      def full_name(test)
        [*groups(test).map(&:name).compact, test.name].join(" > ")
      end

      def invoke(body, fixture, context)
        arguments = (body.arity == 1) ? [] : [fixture]
        context.instance_exec(*arguments, &Runtime.with_self(body))
      end

      def execute(test)
        fixture = {}
        context = ExampleContext.new
        problems = []
        chain = groups(test)
        begin
          chain.each { |group| group.before.each { |hook| invoke(hook, fixture, context) } }
          invoke(test.body, fixture, context)
        rescue StandardError, ScriptError => error
          problems << error
        ensure
          chain.reverse_each do |group|
            group.after.reverse_each do |hook|
              invoke(hook, fixture, context)
            rescue StandardError, ScriptError => error
              problems << error
            end
          end
        end
        problems
      end
    end
  end
end
