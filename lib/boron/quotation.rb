module Boron
  module Quotation
    IR = RubyIR

    private

    def lower_quote(form)
      value = form.datum
      if value.is_a?(Form::Collection)
        call(IR::Local.new("::Boron::Form::#{value.class.name.split("::").last}"), :new,
          IR::ArrayLiteral.new(value.items.map { |item| lower_quote(item) }))
      elsif value.is_a?(Form::Identifier)
        call(IR::Local.new("::Boron::Form::#{value.class.name.split("::").last}"), :new, literal(value.name))
      else
        literal(value)
      end
    end

    def lower_quasiquote(form, environment, depth = 1)
      value = form.datum
      return lower_quote(form) unless value.is_a?(Form::Collection)
      name = value.is_a?(Form::List) ? SyntaxData.name(value.items.first) : nil
      if ["unquote", "unquote-splicing", "quasiquote"].include?(name)
        args = value.items.drop(1)
        arity(args, 1..1, form)
        if name == "unquote" && depth == 1
          return lower(args.first, environment)
        elsif name == "unquote-splicing" && depth == 1
          error("unquote-splicing must appear inside a collection", form)
        end
        inner_depth = (name == "quasiquote") ? depth + 1 : depth - 1
        items = [lower_quote(value.items.first), lower_quasiquote(args.first, environment, inner_depth)]
        return call(IR::Local.new("::Boron::Form::List"), :new, IR::ArrayLiteral.new(items))
      end
      parts = value.items.map do |item|
        if depth == 1 && item.datum.is_a?(Form::List) && SyntaxData.name(item.datum.items.first) == "unquote-splicing"
          args = item.datum.items.drop(1)
          arity(args, 1..1, item)
          call(IR::Local.new("::Boron::Runtime"), :splice, lower(args.first, environment))
        else
          IR::ArrayLiteral.new([lower_quasiquote(item, environment, depth)])
        end
      end
      elements = call(IR::ArrayLiteral.new(parts), :flatten, literal(1))
      call(IR::Local.new("::Boron::Form::#{value.class.name.split("::").last}"), :new, elements)
    end
  end
end
