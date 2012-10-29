class Object
  # Returns whether this object is a collection capable of holding heterogenous items.
  # An Object is a not a collection by default. Subclasses can override this method.
  def collection?
    false
  end
end

module Enumerable
  # Overrides {Object#collection?} to returns +true+, since an Enumerable is capable of
  # holding heterogenous items by default. Subclasses can override this method.
  def collection?
    true
  end
end

class String
  # Overrides {Enumerable#collection?} to returns +false+, since a String is constrained
  # to hold characters.
  def collection?
    false
  end
end

module Jinx
  # The Collection mix-in designates an application-defined Enumerable class.
  module Collection
    include Enumerable
  end
end

module Java::JavaUtil::Collection
  include Jinx::Collection
end
