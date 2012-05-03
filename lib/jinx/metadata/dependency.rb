require 'jinx/helpers/validation'

module Jinx
  # Metadata mix-in to capture Resource dependency.
  module Dependency
    # @return [<Class>] the owner classes
    attr_reader :owners
    
    # @return [<Symbol>] the owner reference attributes
    attr_reader :owner_attributes

    # Adds the given attribute as a dependent.
    #
    # If the attribute inverse is not a collection, then the attribute writer
    # is modified to delegate to the dependent owner writer. This enforces
    # referential integrity by ensuring that the following post-condition holds:
    # *  _owner_._attribute_._inverse_ == _owner_
    # where:
    # * _owner_ is an instance this attribute's declaring class
    # * _inverse_ is the owner inverse attribute defined in the dependent class
    #
    # @param [Symbol] attribute the dependent to add
    # @param [<Symbol>] flags the attribute qualifier flags
    def add_dependent_attribute(attribute, *flags)
      prop = property(attribute)
      logger.debug { "Marking #{qp}.#{attribute} as a dependent attribute of type #{prop.type.qp}..." }
      flags << :dependent unless flags.include?(:dependent)
      prop.qualify(*flags)
      inverse = prop.inverse
      inv_type = prop.type
      # example: Parent.add_dependent_attribute(:children) with inverse :parent calls the following:
      #   Child.add_owner(Parent, :children, :parent)
      inv_type.add_owner(self, attribute, inverse)
      logger.debug { "Marked #{qp}.#{attribute} as a dependent attribute with inverse #{inv_type.qp}#{inverse}." }
    end
    
    # @return [Boolean] whether this class depends on an owner
    def dependent?
      not owners.empty?
    end

    # @param [Class] other the class to check
    # @param [Boolean] recursive whether to check if this class depends on a dependent
    #   of the other class
    # @return [Boolean] whether this class depends on the other class
    def depends_on?(other, recursive=false)
      owners.detect do |owner|
        other <= owner or (recursive and depends_on_recursive?(owner, other))
      end
    end

    # @param [Class] klass the dependent type
    # @return [Symbol, nil] the attribute which references the dependent type, or nil if none
    def dependent_attribute(klass)
      most_specific_domain_attribute(klass, dependent_attributes)
    end
    
    # @return [<Property>] the owner properties
    def owner_properties
      @ops ||= create_owner_properties_enumerator
    end

    # @return [<Symbol>] this class's owner attributes
    def owner_attributes
      @oas ||= owner_properties.transform { |op| op.attribute }
    end
    
    # @return [Boolean] whether this {Resource} class is dependent and reference its owners
    def bidirectional_dependent?
      dependent? and not owner_attributes.empty?
    end

    # @return [<Class>] this class's dependent types
    def dependents
      dependent_attributes.wrap { |da| da.type }
    end

    # @return [<Class>] this class's owner types
    def owners
      @owners ||= Enumerable::Enumerator.new(owner_property_hash, :each_key)
    end

    # @return [Property, nil] the sole owner attribute metadata of this class, or nil if there
    #   is not exactly one owner
    def owner_property
      props = owner_properties
      props.first if props.size == 1
    end

    # @return [Symbol, nil] the sole owner attribute of this class, or nil if there
    #   is not exactly one owner
    def owner_attribute
      prop = owner_property || return
      prop.attribute
    end
    
    # @return [Class, nil] the sole owner type of this class, or nil if there
    #   is not exactly one owner
    def owner_type
      prop = owner_property || return
      prop.type
    end

    protected

    # Adds the given owner class to this dependent class.
    # This method must be called before any dependent attribute is accessed.
    # If the attribute is given, then the attribute inverse is set.
    # Otherwise, if there is not already an owner attribute, then a new owner attribute is created.
    # The name of the new attribute is the lower-case demodulized owner class name.
    #
    # @param [Class] the owner class
    # @param [Symbol] inverse the owner -> dependent attribute
    # @param [Symbol, nil] attribute the dependent -> owner attribute, if known
    # @raise [ValidationError] if the inverse is nil
    def add_owner(klass, inverse, attribute=nil)
      if inverse.nil? then
        raise ValidationError.new("Owner #{klass.qp} missing dependent attribute for dependent #{qp}")
      end
      logger.debug { "Adding #{qp} owner #{klass.qp}#{' attribute ' + attribute.to_s if attribute} with inverse #{inverse}..." }
      if @owner_prop_hash then
        raise MetadataError.new("Can't add #{qp} owner #{klass.qp} after dependencies have been accessed")
      end
      
      # detect the owner attribute, if necessary
      attribute ||= detect_owner_attribute(klass, inverse)
      prop = property(attribute) if attribute
      # Add the owner class => attribute entry.
      # The attribute is nil if the dependency is unidirectional, i.e. there is an owner class which
      # references this class via a dependency attribute but there is no inverse owner attribute.
      local_owner_property_hash[klass] = prop
      # If the dependency is unidirectional, then our job is done.
      if attribute.nil? then
        logger.debug { "#{qp} owner #{klass.qp} has unidirectional inverse #{inverse}." }
        return
      end

      # Bi-directional: add the owner property
      local_owner_properties << prop
      # set the inverse if necessary
      unless prop.inverse then
        set_attribute_inverse(attribute, inverse)
      end
      # set the owner flag if necessary
      unless prop.owner? then prop.qualify(:owner) end

      # Redefine the writer method to warn when changing the owner.
      rdr, wtr = prop.accessors
      redefine_method(wtr) do |old_wtr|
        lambda do |ref|
          prev = send(rdr)
          send(old_wtr, ref)
          if prev and prev != ref then
            if ref.nil? then
              logger.warn("Unset the #{self} owner #{attribute} #{prev}.")
            elsif ref.key != prev.key then
              logger.warn("Reset the #{self} owner #{attribute} from #{prev} to #{ref}.")
            end
          end
          ref
        end
      end
      logger.debug { "Injected owner change warning into #{qp}.#{attribute} writer method #{wtr}." }
      logger.debug { "#{qp} owner #{klass.qp} attribute is #{attribute} with inverse #{inverse}." }
    end
    
    # Adds the given attribute as an owner. This method is called when a new attribute is added that
    # references an existing owner.
    #
    # @param [Symbol] attribute the owner attribute
    def add_owner_attribute(attribute)
      prop = property(attribute)
      otype = prop.type
      hash = local_owner_property_hash
      if hash.include?(otype) then
        oa = hash[otype]
        unless oa.nil? then
          raise MetadataError.new("Cannot set #{qp} owner attribute to #{attribute} since it is already set to #{oa}")
        end
        hash[otype] = prop
      else
        add_owner(otype, prop.inverse, attribute)
      end
    end

    # @return [{Class => Property}] this class's owner type => property hash
    def owner_property_hash
      @op_hash ||= create_owner_property_hash
    end
    
    private

    # @param [Class] klass the class to check
    # @param [Boolean] recursive whether to check whether this class depends on a dependent
    #   of the other class
    # @return [Boolean] whether the owner class depends on the other class
    def depends_on_recursive?(klass, other)
      klass != self and klass.owners.any? { |owner| owner.depends_on?(other, true) }
    end
    
    # @param [<Symbol>] attributes the order in which the effective owner attribute should be determined
    def order_owner_attributes(*attributes)
      @ops = @ops_local = attributes.map { |oa| property(oa) }
    end
    
    def local_owner_property_hash
      @local_oa_hash ||= {}
    end

    # @return [{Class => Property}] a new owner type => attribute hash
    def create_owner_property_hash
      local = local_owner_property_hash
      Class === self && superclass < Resource ? local.union(superclass.owner_property_hash) : local
    end
    
    # @return [<Property>] the owner properties defined in this class
    def local_owner_properties
      @ops_local ||= []
    end
    
    # @return [<Property>] the owner properties defined in the class hierarchy
    def create_owner_properties_enumerator
      local = local_owner_properties
      Class === self && superclass < Resource ? local.union(superclass.owner_properties) : local
    end
    
    # Returns the attribute which references the owner. The owner attribute is the inverse
    # of the given owner class inverse attribute, if it exists. Otherwise, the owner
    # attribute is inferred by #{Inverse#detect_inverse_attribute}.

    # @param klass (see #add_owner)
    # @param [Symbol] inverse the owner -> dependent attribute
    # @return [Symbol, nil] this class's owner attribute
    def detect_owner_attribute(klass, inverse)
      ia = klass.property(inverse).inverse || detect_inverse_attribute(klass)
      if ia then
        logger.debug { "#{qp} reference to owner #{klass.qp} with inverse #{inverse} is #{ia}." }
      else
        logger.debug { "#{qp} reference to owner #{klass.qp} with inverse #{inverse} was not detected." }
      end
      ia
    end
  end
end