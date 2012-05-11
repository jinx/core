module Jinx
  module Math
    # @param [<Numeric>] the numbers to compare
    # @return [Numeric] the smallest number
    def self.min(*args)
      args.inject { |m, n| m < n ? m : n }
    end
    
    # @param [<Numeric>] the numbers to compare
    # @return [Numeric] the largest number
    def self.max(*args)
      args.inject { |m, n| m < n ? n : m }
    end
    
    # @param value the value to check
    # @return [Boolean] whether the value is a Ruby or Java number
    def self.numeric?(value)
      Numeric === value or Java::JavaLang::Number === value
    end
  end
end
