require 'set'
require 'jinx/helpers/inflector'
require 'jinx/helpers/collections'

require 'jinx/helpers/validation'
require 'jinx/metadata/java_property'

module Jinx
  # The PropertyCharacteristics mix-in queries the {Property} flags and features.
  module PropertyCharacteristics
    # An attribute is unidirectional if both of the following is true:
    # * there is no distinct {#inverse} attribute
    # * the attribute is not a {#dependent?} with more than one owner
    #
    # @return [Boolean] whether this attribute does not have an inverse
    def unidirectional?
      inverse.nil? and not (dependent? and type.owner_attributes.size > 1)
    end
    
    # @return [Boolean] whether this property has an inverse
    def bidirectional?
      !!@inv_prop
    end

    # @return [Boolean] whether the subject attribute encapsulates a Java attribute
    def java_property?
      JavaProperty === self
    end

    # @return [Boolean] whether the subject attribute returns a domain object or a collection
    #   of domain objects
    def domain?
      # the type must be a Ruby class rather than a Java Class, and include the Domain mix-in
      Class === type and type < Resource
    end

    # @return [Boolean] whether the subject attribute is not a domain object attribute
    def nondomain?
      not domain?
    end

    # @return [Boolean] whether the subject attribute return type is a collection
    def collection?
      @flags.include?(:collection)
    end

    # Returns whether the subject attribute is a dependent on a parent. See the Jinx configuration
    # documentation for a dependency description.
    #
    # @return [Boolean] whether the attribute references a dependent
    def dependent?
      @flags.include?(:dependent)
    end

    # Returns whether the subject attribute must have a value when it is saved
    #
    # @return [Boolean] whether the attribute is mandatory
    def mandatory?
      @declarer.mandatory_attributes.include?(attribute)
    end

    # An attribute is derived if the attribute value is set by setting another attribute, e.g. if this
    # attribute is the inverse of a dependent owner attribute.
    #
    # @return [Boolean] whether this attribute is derived from another attribute
    def derived?
      dependent? and !!inverse
    end

    # An independent attribute is a reference to one or more non-dependent Resource objects.
    # An {#owner?} attribute is independent.
    #
    # @return [Boolean] whether the subject attribute is a non-dependent domain attribute
    def independent?
      domain? and not dependent?
    end

    # @return [Boolean] whether this attribute is a collection with a collection inverse
    def many_to_many?
      return false unless collection?
      inv_prop = inverse_property
      inv_prop and inv_prop.collection?
    end

    # @return [Boolean] whether the subject attribute is a dependency owner
    def owner?
      @flags.include?(:owner)
    end

    # @return [Boolean] whether this is a dependent attribute which has exactly one owner value
    #   chosen from several owner attributes.
    def disjoint?
      @flags.include?(:disjoint)
    end
    
    # @return [Boolean] whether this attribute is a dependent which does not have a Java
    #   inverse owner attribute
    def unidirectional_java_dependent?
      dependent? and java_property? and not bidirectional_java_association?
    end

    # @return [Boolean] whether this is a Java attribute which has a Java inverse
    def bidirectional_java_association?
      inverse and java_property? and inverse_property.java_property?
    end

    protected
    
    # @param [Property] other the other attribute to check
    # @return [Boolean] whether the other attribute restricts this attribute
    def restriction?(other)
      @restrictions and @restrictions.include?(other)
    end 
  end
end
