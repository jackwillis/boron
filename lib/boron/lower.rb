module Boron
  class CompileError < StandardError
    attr_reader :span

    def initialize(message, span:)
      @span = span
      super("#{span.filename}:#{span.start_line}:#{span.start_column}: #{message}")
    end
  end

  class Lower
    include Quotation

    IR = RubyIR

    def initialize
      @counter = 0
    end

    def lower_all(forms, environment: "boron_env")
      IR::Sequence.new(forms.map { |form| lower(form, environment) })
    end

    private

    def lower(form, environment)
      value = form.datum
      env = IR::Local.new(environment)
      case value
      when Form::Identifier
        call(env, :get, binding_literal(value.binding_key), literal(location(form)))
      when Form::Vector
        IR::ArrayLiteral.new(value.items.map { |item| lower(item, environment) })
      when Form::Map
        IR::HashLiteral.new(value.items.each_slice(2).map { |key, item| [lower(key, environment), lower(item, environment)] })
      when Form::Set
        call(IR::Local.new("::Set"), :new, IR::ArrayLiteral.new(value.items.map { |item| lower(item, environment) }))
      when Form::List
        lower_list(form, environment)
      else
        literal(value)
      end
    end

    def lower_list(form, environment)
      items = form.datum.items
      error("empty list cannot be called", form) if items.empty?
      head, *args = items
      name = head.datum.is_a?(Form::Identifier) ? head.datum.name : nil
      env = IR::Local.new(environment)
      case name
      when "quote"
        arity(args, 1..1, form)
        lower_quote(args.first)
      when "quasiquote"
        arity(args, 1..1, form)
        lower_quasiquote(args.first, environment)
      when "unquote", "unquote-splicing"
        error("#{name} outside quasiquote", form)
      when "do"
        lower_all(args, environment: environment)
      when "if"
        arity(args, 2..3, form)
        IR::Conditional.new(lower(args[0], environment), lower(args[1], environment), args[2] ? lower(args[2], environment) : literal(nil))
      when "def"
        arity(args, 2..2, form)
        call(call(env, :root), :define, binding_literal(identifier(args[0])), lower(args[1], environment))
      when "set!"
        arity(args, 2..2, form)
        call(env, :set, binding_literal(identifier(args[0])), lower(args[1], environment), literal(location(args[0])))
      when "let"
        lower_let(args, form, environment)
      when "fn"
        lower_function(args, form, environment)
      else
        if name&.start_with?(".")
          error("method send requires a receiver", form) if args.empty?
          method = name.delete_prefix(".")
          error("empty method name", head) if method.empty?
          call(lower(args[0], environment), :public_send, literal(method.to_sym), *args.drop(1).map { |arg| lower(arg, environment) })
        else
          call(lower(head, environment), :call, *args.map { |arg| lower(arg, environment) })
        end
      end
    end

    def lower_let(args, form, parent)
      error("let requires a binding vector", form) if args.empty?
      bindings = vector(args.first)
      error("let requires an even number of binding forms", args.first) if bindings.length.odd?
      names = bindings.each_slice(2).map { |name, _| identifier(name) }
      error("duplicate let binding", args.first) unless names.uniq.length == names.length
      frames = bindings.each_slice(2).map { |name, value| [fresh("env"), name, value] }
      body = lower_all(args.drop(1), environment: frames.empty? ? parent : frames.last[0])
      frames.each_with_index.to_a.reverse_each do |(environment, name, value), index|
        outer = index.zero? ? parent : frames[index - 1][0]
        definition = call(IR::Local.new(environment), :define, binding_literal(identifier(name)), lower(value, outer))
        body = call(IR::Lambda.new([environment], nil, IR::Sequence.new([definition, body])), :call, call(IR::Local.new(outer), :child))
      end
      body
    end

    def lower_function(args, form, parent)
      error("fn requires a parameter vector", form) if args.empty?
      parameters = vector(args.first)
      names = parameters.map do |parameter|
        (parameter.datum.is_a?(Form::Identifier) && parameter.datum.name == "&") ? "&" : identifier(parameter)
      end
      rest = nil
      if names.include?("&")
        index = names.index("&")
        error("& must precede exactly one final rest parameter", args.first) unless index == names.length - 2 && names.count("&") == 1
        rest = names.last
        names = names.first(index)
      end
      all_names = names + [rest].compact
      error("duplicate fn parameter", args.first) unless all_names.uniq.length == all_names.length
      ruby_parameters = names.map { fresh("arg") }
      ruby_rest = fresh("rest") if rest
      environment = fresh("env")
      expressions = [IR::Assign.new(environment, call(IR::Local.new(parent), :child))]
      all_names.zip(ruby_parameters + [ruby_rest].compact).each do |name, ruby_name|
        expressions << call(IR::Local.new(environment), :define, binding_literal(name), IR::Local.new(ruby_name))
      end
      expressions << lower_all(args.drop(1), environment: environment)
      IR::Lambda.new(ruby_parameters, ruby_rest, IR::Sequence.new(expressions))
    end

    def identifier(form)
      error("expected a binding identifier", form) unless form.datum.is_a?(Form::Identifier)
      name = form.datum.name
      error("invalid binding identifier #{name}", form) if name == "&" || name.start_with?(".") || name.include?("::")
      form.datum.binding_key
    end

    def binding_literal(key)
      key.is_a?(Form::GeneratedIdentifier) ? call(IR::Local.new("::Boron::Form::GeneratedIdentifier"), :new, literal(key.name)) : literal(key)
    end

    def vector(form)
      error("expected a vector", form) unless form.datum.is_a?(Form::Vector)
      form.datum.items
    end

    def arity(args, range, form)
      error("expected #{range} arguments, got #{args.length}", form) unless range.cover?(args.length)
    end

    def fresh(prefix)
      @counter += 1
      "__boron_#{prefix}_#{@counter}"
    end

    def literal(value)
      IR::Literal.new(value)
    end

    def call(receiver, method, *args)
      IR::Call.new(receiver, method, args)
    end

    def location(form)
      span = form.span
      "#{span.filename}:#{span.start_line}:#{span.start_column}"
    end

    def error(message, form)
      raise CompileError.new(message, span: form.span)
    end
  end
end
