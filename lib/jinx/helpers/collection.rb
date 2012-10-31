module Jinx
  # This Collection mix-in augments Enumerable with utility methods.
  module Collection
    # Returns a new Hash generated from this Collection and an optional value generator block.
    # This Enumerable contains the Hash keys. If the value generator block is given to this
    # method then the block is called with each enumerated element as an argument to
    # generate the associated hash value. If no block is given, then the values are nil.
    #
    # @example
    #   [1, 2, 3].hashify { |item| item.modulo(2) } #=> { 1 => 1, 2 => 0, 3 => 1 }
    #   [:a].hashify #=> { :a => nil }
    # @return [Hash]
    def hashify
      hash = {}
      each { |item| hash[item] = yield item if block_given? }
      hash
    end
  
    # Returns a new Hash generated from this Collection and a required value generator block.
    # This Enumerable contains the Hash keys. The block is called with each enumerated
    # element as an argument to generate the associated hash value.
    # Only non-nil, non-empty values are included in the hash.
    #
    # @example
    #   [1, 2, 3].to_compact_hash { |item| item.modulo(2) } #=> { 1 => 1, 2 => 0, 3 => 1 }
    #   [1, 2, 3].to_compact_hash { |n| n.modulo(2) unless item > 2 } #=> {1 => 1, 2 => 0}
    #   [1, 2, 3].to_compact_hash { |n| n > 2 } #=> {1 => false, 2 => false, 3 => true}
    #   [1, 2, 3].to_compact_hash { |n| Array.new(n - 1, n) } #=> {2 => [2], 3 => [2, 3]}
    # @return [Hash]
    # @raise [ArgumentError] if the generator block is not given
    # @see #hashify
    def to_compact_hash
      raise ArgumentError.new("Compact hash builder is missing the value generator block") unless block_given?
      to_compact_hash_with_index { |item, index| yield item }
    end

    # Returns a new Hash generated from this Collection with a block whose arguments include the enumerated item
    # and its index. Every value which is nil or empty is excluded.
    #
    # @example
    #   [1, 2, 3].to_compact_hash_with_index { |item, index| item + index } #=> { 1 => 1, 2 => 3, 3 => 5 }
    # @yield [item, index] the hash value
    # @yieldparam item the enumerated value
    # @yieldparam index the enumeration index
    # @return [Hash] this {Enumerable} converted to a hash by the given block
    def to_compact_hash_with_index
      hash = {}
      self.each_with_index do |item, index|
        next if item.nil?
        value = yield(item, index)
        next if value.nil_or_empty?
        hash[item] = value
      end
      hash
    end

    # This method is functionally equivalent to +to_a.empty+ but is more concise and efficient.
    #
    # @return [Boolean] whether this Collection iterates over at least one item
    def empty?
      not any? { true }
    end

    # This method is functionally equivalent to +to_a.first+ but is more concise and efficient.
    #
    # @return the first enumerated item in this Collection, or nil if this Collection is empty
    def first
      detect { true }
    end

    # This method is functionally equivalent to +to_a.last+ but is more concise and efficient.
    #
    # @return the last enumerated item in this Collection, or nil if this Collection is empty
    def last
      detect { true }
    end

    # This method is functionally equivalent to +to_a.size+ but is more concise and efficient
    # for an Enumerable which does not implement the {#size} method.
    #
    # @return [Integer] the count of items enumerated in this Collection
    def size
      inject(0) { |size, item| size + 1 }
    end

    alias :length :size

    # @return [String] the content of this Collection as a series using {Array#to_series}
    def to_series(conjunction=nil)
      to_a.to_series
    end

    # Returns the first non-nil, non-false enumerated value resulting from a call to the block given to this method,
    # or nil if no value detected.
    #
    # @example
    #   [1, 2].detect_value { |item| item / 2 if item % 2 == 0 } #=> 1
    # @return [Object] the detected block result
    # @see #detect_with_value
    def detect_value
      each do |*item|
        value = yield(*item)
        return value if value
      end
      nil
    end

    # Returns the first item and value for which an enumeration on the block given to this method returns
    # a non-nil, non-false value.
    #
    # @example
    #   [1, 2].detect_with_value { |item| item / 2 if item % 2 == 0 } #=> [2, 1]
    # @return [(Object, Object)] the detected [item, value] pair
    # @see #detect_value
    def detect_with_value
      value = nil
      match = detect do |*item|
        value = yield(*item)
      end
      [match, value]
    end

    # Returns a new Enumerable that iterates over the base Enumerable items for which filter evaluates to a non-nil,
    #  non-false value, e.g.:
    #   [1, 2, 3].filter { |n| n != 2 }.to_a #=> [1, 3]
    #
    # Unlike select, filter reflects changes to the base Enumerable, e.g.:
    #   a = [1, 2, 3]
    #   filter = a.filter { |n| n != 2 }
    #   a << 4
    #   filter.to_a #=> [1, 3, 4]
    #
    # In addition, filter has a small, fixed storage requirement, making it preferable to select for large collections.
    # Note, however, that unlike select, filter does not return an Array.
    # The default filter block returns the passed item.
    #
    # @example
    #   [1, nil, 3].filter.to_a #=> [1, 3]
    # @yield [item] filter the selection filter
    # @yieldparam item the collection member to filter
    # @return [Enumerable] the filtered result
    def filter(&filter)
      Jinx::Filter.new(self, &filter)
    end

    # @return [Enumerable] an iterator over the non-nil items in this Collection
    def compact
      filter { |item| not item.nil? }
    end

    # @example
    #   {:a => {:b => :c}, :d => [:e]}.enum_values.flatten.to_a #=> [:b, :c, :e]
    # @return [Enumerable] the flattened result
    def flatten
      Jinx::Flattener.new(self).to_a
    end

    # Returns an Enumerable which iterates over items in this Collection and the other Enumerable in sequence.
    # Unlike the Array plus (+) operator, {#union} reflects changes to the underlying enumerators.
    #
    # @quirk Cucumber Cucumber defines it's own Enumerable union monkey-patch. Work around this in the short
    #   term by trying to call the super first.
    #
    # @example
    #   a = [1, 2]
    #   b = [4, 5]
    #   ab = a.union(b)
    #   ab #=> [1, 2, 4, 5]
    #   a << 3
    #   a + b #=> [1, 2, 4, 5]
    #   ab #=> [1, 2, 3, 4, 5]
    # @param [Enumerable] other the Enumerable to compose with this Collection
    # @return [Enumerable] an enumerator over self followed by other
    # @yield (see Jinx::MultiEnumerator#intializer)
    def union(other, &appender)
      Jinx::MultiEnumerator.new(self, other, &appender)
    end

    alias :+ :union

    # @return an Enumerable which iterates over items in this Collection but not the other Enumerable
    def difference(other)
      filter { |item| not other.include?(item) }
    end

    alias :- :difference

    # @return an Enumerable which iterates over items in this Collection which are also in the other
    #   Enumerable
    def intersect(other)
      filter { |item| other.include?(item) }
    end

    alias :& :intersect

    # Returns a new Enumerable that iterates over the base Enumerable applying the transformer block
    # to each item, e.g.:
    #   [1, 2, 3].transform_value { |n| n * 2 }.to_a #=> [2, 4, 6]
    #
    # Unlike Array.map, {#wrap} reflects changes to the base Enumerable, e.g.:
    #   a = [2, 4, 6]
  ``#   transformed = a.wrap { |n| n * 2 }
    #   a << 4
    #   transformed.to_a #=> [2, 4, 6, 8]
    #
    # In addition, transform has a small, fixed storage requirement, making it preferable to select
    # for large collections. Note, however, that unlike map, transform does not return an Array.
    #
    # @yield [item] the transformer on the enumerated items
    # @yieldparam item an enumerated item
    # @return [Enumerable] an enumeration on the transformed values
    def transform(&mapper)
      Jinx::Transformer.new(self, &mapper)
    end
  
    alias :wrap :transform
  
    def join(sep = $,)
      to_a.join(sep)
    end
  
    # Sorts this collection's members with a partial comparator block. A partial
    # comparator block  returns -1, 0, 1 or nil. The resulting sorted order places
    # comparable items in their relative sort order. If two items are not
    # directly comparable, then the relative order of those items is
    # indeterminate. In all cases the relative order is transitive, i.e.:
    # * a < b and b < c => a occurs before c in the sort result
    # * a > b and b > c => a occurs after c in the sort result
    #
    # @example
    #    sorted = [Enumerable, Array, String].partial_sort
    #    sorted.index(Array) < sorted.index(Enumerable) #=> true
    #    sorted.index(String) < sorted.index(Enumerable) #=> true
    #
    # @yield [item1, item2] the partial comparison result (-1, 0, 1 or nil)
    # @yieldparam item1 an item to compare
    # @yieldparam item2 another item to compare
    # @return [Enumerable] a new collection consisting of the items in this collection
    #   in partial sort order
    def partial_sort(&block)
      copy = dup.to_a
      copy.partial_sort!(&block)
      copy
    end
  
    # Sorts this collection in-place with a partial sort operator block
    #
    # @see #partial_sort
    # @yield (see #partial_sort)
    # @yieldparam (see #partial_sort)
    # @raise [NoMethodError] if this Collection does not support the +sort!+ sort in-place method 
    def partial_sort!
      unless block_given? then return partial_sort! { |item1, item2| item1 <=> item2 } end
      # The comparison hash
      h = Hash.new { |h, k| h[k] = Hash.new }
      sort! do |a, b|
        # * If a and b are comparable, then use the comparison result.
        # * Otherwise, if there is a member c such that (a <=> c) == (c <=> b),
        #   then a <=> b has the transitive comparison result.
        # * Otherwise, a <=> b is arbitrarily set to 1.
        yield(a, b) || h[a][b] ||= -h[b][a] ||= h[a].detect_value { |c, v| v if v == yield(c, b) } || 1
      end
    end
  
    # Sorts this collection's members with a partial sort operator on the results of applying the block.
    #
    # @yield [item] transform the item to a Comparable value
    # @yieldparam item an enumerated item
    # @return [Enumerable] the items in this collection in partial sort order
    def partial_sort_by
      partial_sort { |item1, item2| yield(item1) <=> yield(item2) }
    end
  
    # @yield [item] the transformer on the enumerated items
    # @yieldparam item an enumerated item
    # @return [Enumerable] the mapped values excluding null values
    def compact_map(&mapper)
      wrap(&mapper).compact
    end
  end
end