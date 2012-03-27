module Jinx
  # Boolean marks the +true+ and +false+ primitive objects.
  module Boolean
    # The match for a +true+ String.
    TRUE_REGEXP = /^(t(rue)?|y(es)?|1)$/i
  
    # The match for a +false+ String.
    FALSE_REGEXP = /^(f(alse)?||no?|0)$/i
  
    # Converts the given object to a Boolean as follows:
    # * If the object is nil or Boolean, then the unconverted value
    # * 1 -> true
    # * 0 -> false
    # * A {TRUE_REGEXP} match -> true
    # * A {FALSE_REGEXP} match -> false
    #
    # @param for the object to convert
    # @return [Boolean, nil] the corresponding Boolean
    # @raise [ArgumentError] if the value cannot be converted
    def self.for(obj)
      case obj
      when nil then nil
      when true then true
      when false then false
      when 1 then true
      when 0 then false
      when TRUE_REGEXP then true
      when FALSE_REGEXP then false
      else
        raise ArgumentError.new("Value cannot be converted to boolean: '#{obj}'")
      end
    end
  end
end

class TrueClass
  include Jinx::Boolean
end

class FalseClass
  include Jinx::Boolean
end
