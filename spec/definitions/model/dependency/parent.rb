module Model
  class Parent
    property :children, :dependent
    property :dependent, :dependent
  end
end
