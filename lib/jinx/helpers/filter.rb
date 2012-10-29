module Jinx
  # This Filter helper class applies a selection block to a base enumeration.
  class Filter
    include Collection

    # Initializes this Filter's from the given base enumeration and optional filter test.
    # The default filter test is whether the item is non-nil and not +false+.
    #
    # @param [Enumerable] enum the base enumeration to filter
    # @yield [item] the block called on each item
    # @yieldparam item the enumerated item
    def initialize(enum=[], &filter)
      @base = enum
      @filter = filter
    end

    # Calls the given block on each item which passes this Filter's filter test.
    #
    # @yield [item] the block called on each filtered item
    # @yieldparam item the enumerated item
    def each
      @base.each { |item| yield(item) if @filter ? @filter.call(item) : item }
    end

    # Optimized for a Set base.
    #
    # @param [item] the item to check
    # @return [Boolean] whether the item is a member of this Enumerable
    def include?(item)
      return false if Set === @base and not @base.include?(item)
      super
    end

    # Adds an item to the base Enumerable, if this Filter's base supports it.
    #
    # @param item the item to add
    # @return [Filter] self
    def <<(item)
      @base << item
      self
    end

    # @param [Enumerable] other the Enumerable to merge
    # @return [Array] this Filter's filtered content merged with the other Enumerable
    def merge(other)
      to_a.merge!(other)
    end

    # Merges the other Enumerable into the base Enumerable, if the base supports it.
    #
    # @param other (see #merge)
    # @return [Filter, nil] this Filter's filtered content merged with the other Enumerable
    def merge!(other)
      @base.merge!(other)
      self
    end
  end
end