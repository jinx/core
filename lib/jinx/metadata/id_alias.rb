module Jinx
  # Mix-in for Java classes which have an +id+ attribute.
  # Since +id+ is a reserved Ruby method, this mix-in defines an +identifier+ attribute
  # which fronts the +id+ attribute. This mix-in should be included by any JRuby wrapper
  # class for a Java class or interface which implements an +id+ property.
  module IdAlias
    # Returns the identifier.
    # This method delegates to the Java +id+ attribute reader method.
    #
    # @return [Integer] the identifier value
    def identifier
      getId
    end

    # Sets the identifier to the given value.
    # This method delegates to the Java +id+ attribute writer method.
    #
    # @param [Integer] value the value to set
    def identifier=(value)
      setId(value)
    end
  end
end