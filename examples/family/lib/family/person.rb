module Family
  class Person
    # The household is an independent reference with inverse members.
    property :household, :inverse => :members
  end
end
