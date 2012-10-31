module Jinx
  # Meta-data mix-in to infer and set inverse attributes.
  module Inverse
    # Returns the inverse of the given attribute. If the attribute has an #{Property#inverse_property},
    # then that attribute's inverse is returned. Otherwise, if the attribute is an #{Property#owner?},
    # then the target class dependent attribute which matches this type is returned, if it exists.
    #
    # @param [Property] prop the subject attribute
    # @param [Class, nil] klass the target class
    # @return [Property, nil] the inverse attribute, if any
    def inverse_property(prop, klass=nil)
      inv_prop = prop.inverse_property
      return inv_prop if inv_prop
      if prop.dependent? and klass then
        klass.owner_property_hash.each { |otype, op|
        return op if self <= otype }
      end
    end
    
    protected
    
    # Infers the inverse of the given property declared by this class.
    # A domain attribute is recognized as an inverse according to the
    # {Inverse#detect_inverse_attribute} criterion.
    #
    # @param [Property] property the property to check
    # @return [Symbol, nil] the inverse attribute, or nil if none was
    #   detected
    def infer_property_inverse(property)
      inv = property.type.detect_inverse_attribute(self)
      set_attribute_inverse(property.attribute, inv) if inv
      inv
    end
    
    # Sets the given bi-directional association attribute's inverse.
    #
    # @param [Symbol] attribute the subject attribute
    # @param [Symbol] the attribute inverse
    # @raise [TypeError] if the inverse type is incompatible with this Resource
    def set_attribute_inverse(attribute, inverse)
      prop = property(attribute)
      # the standard attribute
      pa = prop.attribute
      # return if inverse is already set
      return if prop.inverse == inverse
      # the default inverse
      inverse ||= prop.type.detect_inverse_attribute(self)
      # If the attribute is not declared by this class, then make a new attribute
      # metadata specialized for this class.
      unless prop.declarer == self then
        prop = restrict_attribute_inverse(prop, inverse)
      end
      logger.debug { "Setting #{qp}.#{pa} inverse to #{inverse}..." }
      # the inverse attribute meta-data
      inv_prop = prop.type.property(inverse)
      # If the attribute is the many side of a 1:M relation, then delegate to the one side.
      if prop.collection? and not inv_prop.collection? then
        return prop.type.set_attribute_inverse(inverse, pa)
      end
      # This class must be the same as or a subclass of the inverse attribute type.
      unless self <= inv_prop.type then
        raise TypeError.new("Cannot set #{qp}.#{pa} inverse to #{prop.type.qp}.#{pa} with incompatible type #{inv_prop.type.qp}")
      end
      # Set the inverse in the attribute metadata.
      prop.inverse = inverse
      # If attribute is the one side of a 1:M or non-reflexive 1:1 relation, then add the inverse updater.
      unless prop.collection? then
        # Inject adding to the inverse collection into the attribute writer method. 
        add_inverse_updater(pa)
        unless prop.type == inv_prop.type or inv_prop.collection? then
          prop.type.delegate_writer_to_inverse(inverse, pa)
        end
      end
      logger.debug { "Set #{qp}.#{pa} inverse to #{inverse}." }
    end

    # Clears the property inverse, if there is one.
    def clear_inverse(property)
      # the inverse property
      ip = property.inverse_property || return
      # If the property is a collection and the inverse is not, then delegate to
      # the inverse.
      if property.collection? then
        return ip.declarer.clear_inverse(ip) unless ip.collection?
      else
        # Restore the property reader and writer to the Java reader and writer, resp.
        alias_property_accessors(property)
      end
      # Unset the inverse.
      property.inverse = nil
    end
    
    # Detects an unambiguous attribute which refers to the given referencing class.
    # If there is exactly one attribute with the given return type, then that attribute is chosen.
    # Otherwise, the attribute whose name matches the underscored referencing class name is chosen,
    # if any.
    #
    # @param [Class] klass the referencing class
    # @return [Symbol, nil] the inverse attribute for the given referencing class and inverse,
    #   or nil if no owner attribute was detected
    def detect_inverse_attribute(klass)
      # The candidate attributes return the referencing type and don't already have an inverse.
      candidates = domain_attributes.compose { |prop| klass <= prop.type and prop.inverse.nil? }
      pa = detect_inverse_attribute_from_candidates(klass, candidates)
      if pa then
        logger.debug { "#{qp} #{klass.qp} inverse attribute is #{pa}." }
      else
        logger.debug { "#{qp} #{klass.qp} inverse attribute was not detected." }
      end
      pa
    end
    
    # Redefines the attribute writer method to delegate to its inverse writer.
    # This is done to enforce inverse integrity.
    #
    # For a +Person+ attribute +account+ with inverse +holder+, this is equivalent to the following:
    #   class Person
    #     alias :set_account :account=
    #     def account=(acct)
    #       acct.holder = self if acct
    #       set_account(acct)
    #     end
    #   end
    def delegate_writer_to_inverse(attribute, inverse)
      prop = property(attribute)
      # nothing to do if no inverse
      inv_prop = prop.inverse_property || return
      logger.debug { "Delegating #{qp}.#{attribute} update to the inverse #{prop.type.qp}.#{inv_prop}..." }
      # redefine the write to set the dependent inverse
      redefine_method(prop.writer) do |old_writer|
        # delegate to the Jinx::Resource set_inverse method
        lambda { |dep| set_inverse(dep, old_writer, inv_prop.writer) }
      end
    end

    private
    
    # Copies the given attribute metadata from its declarer to this class. The new attribute metadata
    # has the same attribute access methods, but the declarer is this class and the inverse is the
    # given inverse attribute.
    #
    # @param [Property] prop the attribute to copy
    # @param [Symbol] the attribute inverse
    # @return [Property] the copied attribute metadata
    def restrict_attribute_inverse(prop, inverse)
      logger.debug { "Restricting #{prop.declarer.qp}.#{prop} to #{qp} with inverse #{inverse}..." }
      rst_prop = prop.restrict(self, :inverse => inverse)
      logger.debug { "Restricted #{prop.declarer.qp}.#{prop} to #{qp} with inverse #{inverse}." }
      rst_prop
    end
    
    # @param klass (see #detect_inverse_attribute)
    # @param [<Symbol>] candidates the attributes constrained to the target type
    # @return (see #detect_inverse_attribute)
    def detect_inverse_attribute_from_candidates(klass, candidates)
      return if candidates.empty?
      # There can be at most one owner attribute per owner.
      return candidates.first.to_sym if candidates.size == 1
      # By convention, if more than one attribute references the owner type,
      # then the attribute named after the owner type is the owner attribute.
      tgt = klass.name.demodulize.underscore.to_sym
      tgt if candidates.detect { |pa| pa == tgt }
    end
    
    # Modifies the given attribute writer method to update the given inverse.
    #
    # @param (see #set_attribute_inverse)
    def add_inverse_updater(attribute)
      prop = property(attribute)
      # the reader and writer methods
      rdr, wtr = prop.accessors
      # the inverse attribute metadata
      inv_prop = prop.inverse_property
      # the inverse attribute reader and writer
      inv_rdr, inv_wtr = inv_accessors = inv_prop.accessors
      # Redefine the writer method to update the inverse by delegating to the inverse.
      redefine_method(wtr) do |old_wtr|
        # the attribute reader and (superseded) writer
        accessors = [rdr, old_wtr]
        if inv_prop.collection? then
          lambda { |other| add_to_inverse_collection(other, accessors, inv_rdr) }
        else
          lambda { |other| set_inversible_noncollection_attribute(other, accessors, inv_wtr) }
        end
      end
      logger.debug { "Injected inverse #{inv_prop} updater into #{qp}.#{attribute} writer method #{wtr}." }
    end
  end
end