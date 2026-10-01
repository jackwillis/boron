module Boron
  class UnboundName < StandardError; end

  class Environment
    attr_reader :parent

    def initialize(parent = nil)
      @parent = parent
      @bindings = {}
    end

    def child
      self.class.new(self)
    end

    def root
      parent ? parent.root : self
    end

    def define(name, value)
      @bindings[name] = value
    end

    def get(name, location)
      return @bindings[name] if @bindings.key?(name)
      return parent.get(name, location) if parent
      if /\A[A-Z]\w*(?:::[A-Z]\w*)*\z/.match?(name)
        return name.split("::").reduce(Object) { |scope, part| scope.const_get(part, false) }
      end
      raise UnboundName, "#{location}: unbound identifier #{name}"
    end

    def set(name, value, location)
      return @bindings[name] = value if @bindings.key?(name)
      return parent.set(name, value, location) if parent
      raise UnboundName, "#{location}: cannot assign unbound identifier #{name}"
    end
  end

  module Runtime
    module_function

    def environment
      env = Environment.new
      {"+" => [:+, 0], "*" => [:*, 1]}.each do |name, (method, identity)|
        env.define(name, ->(*values) { values.empty? ? identity : values.reduce { |a, b| a.public_send(method, b) } })
      end
      env.define("-", ->(first, *rest) { rest.empty? ? -first : rest.reduce(first) { |a, b| a - b } })
      env.define("/", ->(first, second, *rest) { rest.reduce(first / second) { |a, b| a / b } })
      env.define("%", ->(a, b) { a % b })
      {"=" => :==, "==" => :==, "!=" => :!=, "<" => :<, "<=" => :<=, ">" => :>, ">=" => :>=}.each do |name, method|
        env.define(name, ->(a, b, *rest) { [a, b, *rest].each_cons(2).all? { |x, y| x.public_send(method, y) } })
      end
      env.define("not", ->(value) { !value })
      env.define("puts", ->(*values) { Kernel.puts(*values) })
      env.define("print", ->(*values) { Kernel.print(*values) })
      env.define("require", ->(path) { Kernel.require(path) })
      env.define("get", ->(collection, key) { collection[key] })
      env.define("send", ->(receiver, method, *args) { receiver.public_send(method, *args) })
      env.define("send-with-block", ->(receiver, method, args, block) { receiver.public_send(method, *args, &block) })
      env
    end
  end
end
