module Boron
  module Printer
    module_function

    def format(value, ancestors = [])
      return "#<cycle>" if ancestors.include?(value.object_id)
      return "#<depth limit>" if ancestors.length >= 30
      nested = ancestors + [value.object_id]
      item = ->(child) { format(child, nested) }
      case value
      when Form::Identifier then value.name
      when Form::List then "(#{value.items.map(&item).join(" ")})"
      when Form::Vector, Array then "[#{value.to_a.map(&item).join(" ")}]"
      when Form::Map then "{#{value.items.map(&item).join(" ")}}"
      when Form::Set, ::Set then "\#{#{value.to_a.map(&item).join(" ")}}"
      when Hash then "{#{value.flat_map { |key, child| [item.call(key), item.call(child)] }.join(" ")}}"
      else value.inspect
      end
    end
  end
end
