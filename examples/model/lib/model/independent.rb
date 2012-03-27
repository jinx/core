module Model
  class Independent
    # The others property is a M:N association without a parameterized type.
    # Specify the type here, since it cannot be introspected. The inverse
    # of a source object is the target object others property value.
    property :others, :type => self, :inverse => :others
    
    # The secondary key is the name.
    property :name, :secondary_key
  end
end
