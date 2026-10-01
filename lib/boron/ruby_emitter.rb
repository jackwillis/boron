module Boron
  class RubyEmitter
    IR = RubyIR

    def emit(node)
      case node
      when IR::Literal
        node.value.is_a?(String) ? "#{node.value.dump}.dup" : node.value.inspect
      when IR::Local
        node.name
      when IR::Assign
        "#{node.name} = #{emit(node.value)}"
      when IR::Call
        "(#{emit(node.receiver)}).#{node.method}(#{node.arguments.map { |argument| emit(argument) }.join(", ")})"
      when IR::ArrayLiteral
        "[#{node.items.map { |item| emit(item) }.join(", ")}]"
      when IR::HashLiteral
        "{#{node.pairs.map { |key, value| "#{emit(key)} => #{emit(value)}" }.join(", ")}}"
      when IR::Sequence
        expressions = node.expressions.map { |expression| emit(expression) }
        expressions.empty? ? "nil" : "(begin\n#{indent(expressions.join("\n"))}\nend)"
      when IR::Conditional
        "(if #{emit(node.condition)}\n#{indent(emit(node.consequent))}\nelse\n#{indent(emit(node.alternative))}\nend)"
      when IR::Lambda
        parameters = node.parameters.dup
        parameters << "*#{node.rest}" if node.rest
        "->(#{parameters.join(", ")}) do\n#{indent(emit(node.body))}\nend"
      else
        raise ArgumentError, "unknown Ruby IR node: #{node.class}"
      end
    end

    private

    def indent(source)
      source.lines.map { |line| "  #{line}" }.join
    end
  end
end
