module Model
  class Parent
    # A parent owns children. This dependency is flagged as logical, indicating
    # that a persistence service must explicitly save the referenced children
    # when saving the parent.
    property :children, :dependent, :logical
    
    # The parent dependent attribute references a Dependent. The dependent
    # attribute is, not surprisingly, designated as a dependent reference.
    property :dependent, :dependent
    
    # The spouse is an independent reference. The spouse is an idempotent inverse,
    # i.e. parent = parent.spouse.spouse.
    property :spouse, :inverse => :spouse
    
    # The secondary key is the name.
    property :name, :secondary_key
  end
end
