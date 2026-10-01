module Boron
  module RubyIR
    Literal = Data.define(:value)
    Local = Data.define(:name)
    Assign = Data.define(:name, :value)
    Call = Data.define(:receiver, :method, :arguments)
    ArrayLiteral = Data.define(:items)
    HashLiteral = Data.define(:pairs)
    Sequence = Data.define(:expressions)
    Conditional = Data.define(:condition, :consequent, :alternative)
    Lambda = Data.define(:parameters, :rest, :body)
  end
end
