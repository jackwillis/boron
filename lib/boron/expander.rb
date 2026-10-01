module Boron
  class Expander
    RESERVED = %w[quote quasiquote unquote unquote-splicing macroexpand defmacro def let fn if do set!].freeze
    MAX_DEPTH = 100

    def initialize
      @environment = Runtime.environment
      @macros = {}
      core = File.join(__dir__, "core.bn")
      expand_all(Reader.new(File.read(core), filename: core).read_all)
    end

    def expand_all(forms)
      forms.map do |form|
        if head_name(form) == "defmacro"
          register(form)
          Syntax.new(nil, form.span)
        else
          expand(form)
        end
      end
    end

    def expand(form, depth = 0)
      raise CompileError.new("macro expansion exceeded #{MAX_DEPTH} nested calls", span: form.span) if depth > MAX_DEPTH
      value = form.datum
      return form unless value.is_a?(Form::Collection)
      name = head_name(form)
      return form if name == "quote"
      if name == "defmacro"
        raise CompileError.new("defmacro is only supported at top level", span: form.span)
      elsif name == "quasiquote"
        return walk_quasiquote(form, depth)
      elsif name == "macroexpand"
        args = value.items.drop(1)
        unless args.length == 1 && head_name(args.first) == "quote" && args.first.datum.items.length == 2
          raise CompileError.new("macroexpand expects one quoted form", span: form.span)
        end
        expanded = expand(args.first.datum.items.last, depth)
        return Syntax.new(Form::List.new([value.items.first.then { |head| Syntax.new(Form::Identifier.new("quote"), head.span) }, expanded]), form.span)
      elsif @macros.key?(name)
        origins = {}
        arguments = value.items.drop(1).map { |item| SyntaxData.datum(item, origins: origins) }
        begin
          result = @macros.fetch(name).call(*arguments)
          generated = SyntaxData.wrap(result, span: form.span, origin: MacroOrigin.new(name, form.span), origins: origins)
        rescue => error
          raise CompileError.new("macro #{name}: #{error.class}: #{error.message}", span: form.span)
        end
        return expand(generated, depth + 1)
      end
      Syntax.new(value.class.new(value.items.map { |item| expand(item, depth) }), form.span, form.origin)
    end

    private

    def register(form)
      _, name, parameters, *body = form.datum.items
      unless name&.datum.is_a?(Form::Identifier) && parameters&.datum.is_a?(Form::Vector)
        raise CompileError.new("defmacro requires a name and parameter vector", span: form.span)
      end
      if RESERVED.include?(name.datum.name)
        raise CompileError.new("cannot redefine special form #{name.datum.name} as a macro", span: name.span)
      end
      function = Syntax.new(Form::List.new([Syntax.new(Form::Identifier.new("fn"), form.span), parameters, *body]), form.span)
      ruby = RubyEmitter.new.emit(Lower.new.lower_all([expand(function)]))
      boron_env = @environment
      # Macro functions use the same Ruby backend in an isolated phase environment.
      callable = Kernel.eval(ruby, binding, form.span.filename) # standard:disable Security/Eval
      @macros[name.datum.name] = callable
      @environment.define(name.datum.name, callable)
    end

    def head_name(form)
      SyntaxData.name(form.datum.items.first) if form&.datum.is_a?(Form::List)
    end

    def walk_quasiquote(form, expansion_depth, quote_depth = 0)
      value = form.datum
      return form unless value.is_a?(Form::Collection)
      name = head_name(form)
      if name == "quasiquote"
        quote_depth += 1
      elsif ["unquote", "unquote-splicing"].include?(name)
        children = value.items.each_with_index.map do |item, index|
          if index.zero?
            item
          elsif quote_depth == 1
            expand(item, expansion_depth)
          else
            walk_quasiquote(item, expansion_depth, quote_depth - 1)
          end
        end
        return Syntax.new(value.class.new(children), form.span, form.origin)
      end
      Syntax.new(value.class.new(value.items.map { |item| walk_quasiquote(item, expansion_depth, quote_depth) }), form.span, form.origin)
    end
  end
end
