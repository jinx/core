module Model
  class Child
    # The friends property has a pals 
    property :friends, :alias => :pals
    
    # The default cardinal value is 1.
    property :cardinal, :default => 1
    
    # The secondary key is the name scoped by the parent.
    property :parent, :secondary_key
    property :name, :secondary_key
  end
end