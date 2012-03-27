module Model
  class Child
    property :parent, :inverse => :children
  end
end