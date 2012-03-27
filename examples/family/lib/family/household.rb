module Family
  class Household
    # The household owns its address.
    property :address, :dependent
  end
end
