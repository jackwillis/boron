require "set" unless defined?(::Set) # standard:disable Lint/RedundantRequireStatement

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
      if name.is_a?(String) && /\A[A-Z]\w*(?:::[A-Z]\w*)*\z/.match?(name)
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
    CONSTANT_PATH = /\A[A-Z][A-Za-z0-9_]*(?:::[A-Z][A-Za-z0-9_]*)*\z/

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
      env.define("put", ->(collection, key, value) { collection[key] = value })
      env.define("map", ->(function, collection) { collection.map { |value| function.call(value) } })
      env.define("filter", ->(predicate, collection) { collection.select { |value| predicate.call(value) } })
      env.define("reduce", ->(function, initial, collection) { collection.reduce(initial) { |result, value| function.call(result, value) } })
      env.define("group-by", ->(function, collection) { collection.group_by { |value| function.call(value) } })
      env.define("count", ->(collection) { collection.count })
      env.define("list", ->(*values) { Form::List.new(values) })
      env.define("vector", ->(*values) { Form::Vector.new(values) })
      env.define("list?", ->(value) { value.is_a?(Form::List) })
      env.define("first", ->(values) { values.first })
      env.define("rest", ->(values) { values.drop(1) })
      env.define("cons", ->(value, values) { Form::List.new([value, *values.to_a]) })
      env.define("concat", ->(*collections) { collections.flat_map(&:to_a) })
      env.define("apply", ->(function, values) { function.call(*values.to_a) })
      env.define("gensym", ->(prefix = "g") { gensym(prefix) })
      env.define("send", ->(receiver, method, *args) { receiver.public_send(method, *args) })
      env.define("send-with-block", ->(receiver, method, args, block) { send_with_block(receiver, method, args, block) })
      env.define("ivar-get", ->(receiver, name) { receiver.instance_variable_get(ivar_name(name)) })
      env.define("ivar-set!", ->(receiver, name, value) { receiver.instance_variable_set(ivar_name(name), value) })
      env.define("ivar-defined?", ->(receiver, name) { receiver.instance_variable_defined?(ivar_name(name)) })
      env.define("with-self", ->(function) { with_self(function) })
      env
    end

    def gensym(prefix)
      @gensym_counter = (@gensym_counter || 0) + 1
      Form::GeneratedIdentifier.new("#{prefix}__#{@gensym_counter}")
    end

    def send_with_block(receiver, method, arguments, block)
      receiver.public_send(method, *arguments, &block)
    end

    def ivar_name(name)
      unless name.is_a?(String) || name.is_a?(Symbol)
        raise TypeError, "instance variable name must be a String or Symbol"
      end
      text = name.to_s
      text.start_with?("@") ? text : "@#{text}"
    end

    def with_self(function)
      raise TypeError, "with-self requires a callable" unless function.respond_to?(:call)
      proc { |*arguments| function.call(self, *arguments) }
    end

    def constant_name(form)
      unless form.is_a?(Form::Identifier) && CONSTANT_PATH.match?(form.name)
        raise ArgumentError, "declaration requires an uppercase constant name or path"
      end
      form.name
    end

    def declare_module(path)
      owner, name = constant_owner(path)
      if owner.const_defined?(name, false)
        value = owner.const_get(name, false)
        raise TypeError, "#{path} already exists and is not a module" unless value.instance_of?(Module)
        value
      else
        owner.const_set(name, Module.new)
      end
    end

    def declare_class(path, *superclasses)
      raise ArgumentError, "class declaration accepts at most one superclass" if superclasses.length > 1
      superclass = superclasses.empty? ? Object : superclasses.first
      raise TypeError, "superclass must be a Ruby Class" unless superclass.is_a?(Class)
      owner, name = constant_owner(path)
      if owner.const_defined?(name, false)
        value = owner.const_get(name, false)
        raise TypeError, "#{path} already exists and is not a class" unless value.is_a?(Class)
        if !superclasses.empty? && value.superclass != superclass
          raise TypeError, "superclass mismatch for #{path}"
        end
        value
      else
        owner.const_set(name, Class.new(superclass))
      end
    end

    def constant_owner(path)
      raise ArgumentError, "invalid constant path" unless path.is_a?(String) && CONSTANT_PATH.match?(path)
      parts = path.split("::")
      name = parts.pop
      owner = parts.reduce(Object) { |scope, part| scope.const_get(part, false) }
      raise TypeError, "constant namespace must be a Ruby Module or Class" unless owner.is_a?(Module)
      [owner, name]
    end
    private_class_method :constant_owner

    def splice(value)
      return value.items if value.is_a?(Form::List) || value.is_a?(Form::Vector)
      return value if value.is_a?(Array)
      raise TypeError, "unquote-splicing requires a list, vector, or Array"
    end
  end
end
