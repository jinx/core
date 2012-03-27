module Family
  class Parent
    # The SSN is a secondary key
    property :ssn, :secondary_key
    
    # A parent owns children. This dependency is flagged as logical, indicating
    # that the persistence service must explicitly save the referenced children
    # when saving the parent.
    property :children, :dependent, :logical
    
    # The spouse is an independent reference. The spouse is an idempotent inverse,
    # i.e. parent = parent.spouse.spouse.
    property :spouse, :inverse => :spouse
    
    # The household is an independent reference with inverse members.
    property :household, :inverse => :members
  end
end
