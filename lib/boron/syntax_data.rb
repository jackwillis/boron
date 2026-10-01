module Boron
  module SyntaxData
    module_function

    def datum(syntax, origins: {})
      value = syntax.datum
      result = if value.is_a?(Form::Collection)
        value.class.new(value.items.map { |item| datum(item, origins: origins) })
      else
        value
      end
      origins[result.object_id] = syntax if result.is_a?(Form::Collection) || result.is_a?(Form::Identifier)
      result
    end

    def wrap(value, span:, origin: nil, origins: {})
      return origins.fetch(value.object_id) if origins.key?(value.object_id)
      if value.is_a?(Form::Collection)
        children = value.items.map { |item| wrap(item, span: span, origin: origin, origins: origins) }
        value = value.class.new(children)
        raise CompileError.new("macro map needs alternating keys and values", span: span) if value.is_a?(Form::Map) && children.length.odd?
      elsif ![Form::Identifier, String, Symbol, Integer, Float, NilClass, TrueClass, FalseClass].any? { |type| value.is_a?(type) }
        raise CompileError.new("macro must return a form datum, got #{value.class}", span: span)
      end
      Syntax.new(value, span, origin)
    end

    def name(syntax)
      syntax.datum.name if syntax&.datum.is_a?(Form::Identifier)
    end
  end
end
