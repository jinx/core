require 'jinx/resource/uniquifier_cache'

module Jinx
  # The Unique mix-in makes values unique within the scope of a Resource class.
  module Unique
    # Replaces each String secondary and alternate key property with a unique
    # value. Successive calls to this method for domain objects of the same class
    # replace the same String key property values with the same unique value. 
    #
    # @return [Resource] self
    def uniquify
      uniquify_attributes(self.class.secondary_key_attributes)
      uniquify_attributes(self.class.alternate_key_attributes)
      self
    end

    private

    # Makes this domain object's String values for the given attributes unique.
    #
    # @param [<Symbol>] the key attributes to uniquify
    def uniquify_attributes(attributes)
      attributes.each do |ka|
        oldval = send(ka)
        next unless String === oldval
        newval = UniquifierCache.instance.get(self, oldval)
        set_property_value(ka, newval)
        logger.debug { "Reset #{qp} #{ka} from #{oldval} to unique value #{newval}." }
      end
    end
  end
end
