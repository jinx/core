require 'set'
require 'jinx/helpers/inflector'
require 'jinx/helpers/collections'
require 'jinx/helpers/validation'
require 'jinx/metadata/property_characteristics'

module Jinx
  # A Property captures the following metadata about a domain class attribute:
  # * attribute symbol
  # * declarer type
  # * return type
  # * reader method symbol
  # * writer method symbol
  class Property
    include PropertyCharacteristics
     
    # The supported property qualifier flags. See the complementary methods for an explanation of
    # the flag option, e.g. {#dependent?} for the +:dependent+ flag.
    #
    # Included persistence adapters should add specialized flags to this set. An unsupported flag
    # is allowed and can be used by adapters, but a warning log message is issued in that case. 
    SUPPORTED_FLAGS = [
      :collection, :dependent, :disjoint, :owner, :mandatory, :optional].to_set

    # @return [Symbol] the standard attribute symbol for this property
    attr_reader :attribute

    # @return [(Symbol, Symbol)] the standard attribute reader and writer methods
    attr_reader :accessors

    # @return [Class] the declaring class
    attr_reader :declarer
    
    # @return [Class] the return type
    attr_reader :type
    
    # @return [<Symbol>] the qualifier flags
    # @see SUPPORTED_FLAGS
    attr_reader :flags

    # Creates a new Property from the given attribute.
    #
    # The return type is the referenced entity type. An attribute whose return type is a
    # collection of domain objects is thus the domain object class rather than a collection
    # class.
    #
    # @param [String, Symbol] pa the subject attribute
    # @param [Class] declarer the declaring class
    # @param [Class] type the return type
    # @param [<Symbol>] flags the qualifying {#flags}
    def initialize(attribute, declarer, type=nil, *flags)
      # the attribute symbol
      @attribute = attribute.to_sym
      # the declaring class
      @declarer = declarer
      # the Ruby class
      @type = Class.to_ruby(type) if type
      # the read and write methods
      @accessors = [@attribute, "#{attribute}=".to_sym]
      # the qualifier flags
      @flags = Set.new
      qualify(*flags)
    end

    # @return [Symbol] the reader method
    def reader
      accessors.first
    end

    # @return [Symbol] the writer method
    def writer
      accessors.last
    end

    # @return [Symbol, nil] the inverse of this attribute, if any
    def inverse
      @inv_prop.attribute if @inv_prop
    end
    
    # @param [Class] the attribute return type
    def type=(klass)
      return if klass == @type
      @type = klass
      if @inv_prop then
        self.inverse = @inv_prop.attribute
        logger.debug { "Reset #{@declarer.qp}.#{self} inverse from #{@inv_prop.type}.#{@inv_prop} to #{klass}#{@inv_prop}." }
      end
    end
    
    # Creates a new declarer attribute which qualifies this attribute for the given declarer.
    #
    # @param declarer (see #restrict)
    # @param [<Symbol>] flags the additional flags for the restricted attribute
    # @return (see #restrict)
    def restrict_flags(declarer, *flags)
      copy = restrict(declarer)
      copy.qualify(*flags)
      copy
    end

    # Sets the inverse of the subject attribute to the given attribute.
    # The inverse relation is symmetric, i.e. the inverse of the referenced Property
    # is set to this Property's subject attribute.
    #
    # @param [Symbol, nil] attribute the inverse attribute
    # @raise [MetadataError] if the the inverse of the inverse is already set to a different attribute
    def inverse=(attribute)
      return if inverse == attribute
      # if no attribute, then the clear the existing inverse, if any
      return clear_inverse if attribute.nil?
      # the inverse attribute meta-data
      begin
        @inv_prop = type.property(attribute)
      rescue NameError => e
        raise MetadataError.new("#{@declarer.qp}.#{self} inverse attribute #{type.qp}.#{attribute} not found")
      end
      # the inverse of the inverse
      inv_inv_prop = @inv_prop.inverse_property
      # If the inverse of the inverse is already set to a different attribute, then raise an exception.
      if inv_inv_prop and not (inv_inv_prop == self or inv_inv_prop.restriction?(self))
        raise MetadataError.new("Cannot set #{type.qp}.#{attribute} inverse attribute to #{@declarer.qp}.#{self}@#{object_id} since it conflicts with existing inverse #{inv_inv_prop.declarer.qp}.#{inv_inv_prop}@#{inv_inv_prop.object_id}")
      end
      # Set the inverse of the inverse to this attribute.
      @inv_prop.inverse = @attribute
      # If this attribute is disjoint, then so is the inverse.
      @inv_prop.qualify(:disjoint) if disjoint?
      logger.debug { "Assigned #{@declarer.qp}.#{self} attribute inverse to #{type.qp}.#{attribute}." }
    end

    # @return [Property, nil] the property for the {#inverse} attribute, if any
    def inverse_property
      @inv_prop
    end

    # Qualifies this attribute with the given flags. Supported flags are listed in {SUPPORTED_FLAGS}.
    #
    # @param [<Symbol>] the flags to add
    # @raise [ArgumentError] if the flag is not supported
    def qualify(*flags)
      flags.each { |flag| set_flag(flag) }
      # propagate to restrictions
      if @restrictions then @restrictions.each { |prop| prop.qualify(*flags) } end
    end

    # @return [Boolean] this attribute's inverse attribute if the inverse is a derived attribute, or nil otherwise
    def derived_inverse
      @inv_prop.attribute if @inv_prop and @inv_prop.derived?
    end
    
    # Creates a new declarer attribute which restricts this attribute.
    # This method should only be called by a {Resource} class, since the class is responsible
    # for resetting the attribute symbol => meta-data association to point to the new restricted
    # attribute.
    #
    # If this attribute has an inverse, then the restriction inverse is set to the attribute
    # declared by the restriction declarer'. For example, if:
    # * +AbstractProtocol.coordinator+ has inverse +Administrator.protocol+ 
    # * +AbstractProtocol+ has subclass +StudyProtocol+
    # * +StudyProtocol.coordinator+ returns a +StudyCoordinator+
    # * +AbstractProtocol.coordinator+ is restricted to +StudyProtocol+
    # then calling this method on the +StudyProtocol.coordinator+ restriction
    # sets the +StudyProtocol.coordinator+ inverse to +StudyCoordinator.coordinator+.
    #
    # @param [Class] declarer the subclass which declares the new restricted attribute
    # @param [Hash, nil] opts the restriction options
    # @option opts [Class] type the restriction return type (default this attribute's return type)
    # @option opts [Symbol] type the restriction inverse (default this attribute's inverse) 
    # @return [Property] the new restricted attribute
    # @raise [ArgumentError] if the restricted declarer is not a subclass of this attribute's declarer
    # @raise [ArgumentError] if there is a restricted return type and it is not a subclass of this
    #   attribute's return type
    # @raise [MetadataError] if this attribute has an inverse that is not independently declared by
    #   the restricted declarer subclass 
    def restrict(declarer, opts={})
      rtype = opts[:type] || @type
      rinv = opts[:inverse] || inverse
      unless declarer < @declarer then
        raise ArgumentError.new("Cannot restrict #{@declarer.qp}.#{self} to an incompatible declarer type #{declarer.qp}")
      end
      unless rtype <= @type then
        raise ArgumentError.new("Cannot restrict #{@declarer.qp}.#{self}({@type.qp}) to an incompatible return type #{rtype.qp}")
      end
      # Copy this attribute and its instance variables minus the restrictions and make a deep copy of the flags.
      rst = deep_copy
      # specialize the copy declarer
      rst.set_restricted_declarer(declarer)
      # Capture the restriction to propagate modifications to this metadata, esp. adding an inverse.
      @restrictions ||= []
      @restrictions << rst
      # Set the restriction type
      rst.type = rtype
      # Specialize the inverse to the restricted type attribute, if necessary.
      rst.inverse = rinv
      rst
    end
     
    alias :to_sym :attribute

    def to_s
      attribute.to_s
    end

    alias :inspect :to_s

    alias :qp :to_s
    
    protected
    
    # Duplicates the mutable content as part of a {#deep_copy}.
    def dup_content
      # keep the copied flags but don't share them
      @flags = @flags.dup
      # restrictions and inverse are neither shared nor copied
      @inv_prop = @restrictions = nil
    end
    
    # @param [Property] other the other attribute to check
    # @return [Boolean] whether the other attribute restricts this attribute
    def restriction?(other)
      @restrictions and @restrictions.include?(other)
    end 
    
    # @param [Class] klass the declaring class of this restriction attribute
    def set_restricted_declarer(klass)
      if @declarer and not klass < @declarer then
        raise MetadataError.new("Cannot reset #{declarer.qp}.#{self} declarer to #{type.qp}")
      end
      @declarer = klass
      @declarer.add_restriction(self)
    end
    
    private
    
    # @param [Symbol] the flag to set
    # @return [Boolean] whether the flag is supported
    def flag_supported?(flag)
      SUPPORTED_FLAGS.include?(flag)
    end
    
    # Creates a copy of this metadata which does not share mutable content.
    #
    # The copy instance variables are as follows:
    # * the copy inverse and restrictions are empty
    # * the copy flags is a deep copy of this attribute's flags
    # * other instance variable references are shared between the copy and this attribute
    #
    # @return [Property] the copied attribute
    def deep_copy
      other = dup
      other.dup_content
      other
    end
    
    def clear_inverse
      return unless @inv_prop
      logger.debug { "Clearing #{@declarer.qp}.#{self} inverse #{type.qp}.#{inverse}..." }
      # Capture the inverse before unsetting it.
      ip = @inv_prop
      # Unset the inverse.
      @inv_prop = nil
      # Clear the inverse of the inverse.
      ip.inverse = nil
      logger.debug { "Cleared #{@declarer.qp}.#{self} inverse." }
    end
    
    # @param [Symbol] the flag to set
    # @raise [ArgumentError] if the flag is not supported
    def set_flag(flag)
      return if @flags.include?(flag)
      unless flag_supported?(flag) then
        raise ArgumentError.new("Property #{declarer.name}.#{self} flag not supported: #{flag.qp}")
      end
      @flags << flag
      case flag
        when :owner then owner_flag_set
        when :dependent then dependent_flag_set
      end
    end
    
    # This method is called when the owner flag is set.
    # The inverse is inferred as the referenced owner type's dependent attribute which references
    # this attribute's type.
    #
    # @raise [MetadataError] if this attribute is dependent or an inverse could not be inferred
    def owner_flag_set
      if dependent? then
        raise MetadataError.new("#{declarer.qp}.#{self} cannot be set as a #{type.qp} owner since it is already defined as a #{type.qp} dependent")
      end
      inv_attr = type.dependent_attribute(@declarer)
      if inv_attr.nil? then
        raise MetadataError.new("#{@declarer.qp} owner attribute #{self} does not have a #{type.qp} dependent inverse")
      end
      logger.debug { "#{declarer.qp}.#{self} inverse is the #{type.qp} dependent attribute #{inv_attr}." }
      self.inverse = inv_attr
    end
    
    # Validates that this is not an owner attribute.
    #
    # @raise [MetadataError] if this is an owner attribute
    def dependent_flag_set
      if owner? then
        raise MetadataError.new("#{declarer.qp}.#{self} cannot be set as a  #{type.qp} dependent since it is already defined as a #{type.qp} owner")
      end
    end
  end
end
