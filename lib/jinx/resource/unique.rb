require 'jinx/helpers/uniquifier'

module Jinx
  # The Unique mix-in makes values unique within the scope of a Resource class.
  module Unique
    # Makes the given String value unique in the context of this object's class.
    # @return nil if value is nil
    # Raises TypeError if value is neither nil nor a String.
    def uniquify_value(value)
      unless String === value or value.nil? then
        Jinx.fail(TypeError, "Cannot uniquify #{qp} non-String value #{value}")
      end
      Uniquifier.instance.uniquify(self, value)
    end
    
    # Makes the secondary key unique by replacing each String key attribute value
    # with a unique value.
    def uniquify
      uniquify_attributes(self.class.secondary_key_attributes)
      uniquify_attributes(self.class.alternate_key_attributes)
    end
    
    # Makes the given attribute values unique by replacing each String value
    # with a unique value.
    def uniquify_attributes(attributes)
      attributes.each do |ka|
        oldval = send(ka)
        next unless String === oldval
        newval = uniquify_value(oldval)
        set_property_value(ka, newval)
        logger.debug { "Reset #{qp} #{ka} from #{oldval} to unique value #{newval}." }
      end
    end
  end
end
