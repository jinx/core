require 'enumerator'

class Object
  # This base implementation of +enumerate+ calls the given block on self unless
  # this object in nil. If this object is nil, this method is a no-op.
  #
  # @yield [item] the block to apply to this object
  # @yieldparam item self
  def enumerate
    yield(self) unless nil?
  end

  # Returns an enumerator on this Object. This default implementation returns an Enumerable::Enumerator
  # on enumerate.
  #
  # @return [Enumerable] this object as an enumerable item
  def to_enum
    Enumerable::Enumerator.new(self, :enumerate)
  end
end

module Enumerable
  # Synonym for each.
  #
  # @yield [item] the block to apply to each member
  # @yieldparam item a member of this Enumerable
  def enumerate(&block)
    each(&block)
  end

  # @return self
  def to_enum
    self
  end
end
