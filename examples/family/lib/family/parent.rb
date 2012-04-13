module Family
  class Parent
    # The SSN is a secondary key
    property :ssn, :secondary_key
    
    # A parent owns children.
    property :children, :dependent
    
    # The spouse is an independent reference. The spouse is an idempotent inverse,
    # i.e. parent = parent.spouse.spouse.
    property :spouse, :inverse => :spouse
    
    # The household is an independent reference with inverse members.
    property :household, :inverse => :members
  end
end
