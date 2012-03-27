module Model
  class Parent
    property :children, :dependent, :logical
    property :dependent, :dependent
  end
end
