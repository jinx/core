require 'jinx/helpers/transformer'
require 'jinx/helpers/multi_enumerator'

module Enumerable
  # Returns a new Hash generated from this Enumerable and an optional value generator block.
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
  
  # Returns a new Hash generated from this Enumerable and a required value generator block.
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
    Jinx.fail(ArgumentError, "Compact hash builder is missing the value generator block") unless block_given?
    to_compact_hash_with_index { |item, index| yield item }
  end

  # Returns a new Hash generated from this Enumerable with a block whose arguments include the enumerated item
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
  # @return [Boolean] whether this Enumerable iterates over at least one item
  def empty?
    not any? { true }
  end

  # This method is functionally equivalent to +to_a.first+ but is more concise and efficient.
  #
  # @return the first enumerated item in this Enumerable, or nil if this Enumerable is empty
  def first
    detect { true }
  end

  # This method is functionally equivalent to +to_a.last+ but is more concise and efficient.
  #
  # @return the last enumerated item in this Enumerable, or nil if this Enumerable is empty
  def last
    detect { true }
  end

  # This method is functionally equivalent to +to_a.size+ but is more concise and efficient
  # for an Enumerable which does not implement the {#size} method.
  #
  # @return [Integer] the count of items enumerated in this Enumerable
  def size
    inject(0) { |size, item| size + 1 }
  end

  alias :length :size

  # @return [String] the content of this Enumerable as a series using {Array#to_series}
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

  # @return [Enumerable] an iterator over the non-nil items in this Enumerable
  def compact
    filter { |item| not item.nil? }
  end

  # @example
  #   {:a => {:b => :c}, :d => [:e]}.enum_values.flatten.to_a #=> [:b, :c, :e]
  # @return [Enumerable] the flattened result
  def flatten
    Jinx::Flattener.new(self).to_a
  end

  # Returns an Enumerable which iterates over items in this Enumerable and the other Enumerable in sequence.
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
  # @param [Enumerable] other the Enumerable to compose with this Enumerable
  # @return [Enumerable] an enumerator over self followed by other
  def union(other)
    super rescue Jinx::MultiEnumerator.new(self, other)
  end

  alias :+ :union

  # @return an Enumerable which iterates over items in this Enumerable but not the other Enumerable
  def difference(other)
    filter { |item| not other.include?(item) }
  end

  alias :- :difference

  # @return an Enumerable which iterates over items in this Enumerable which are also in the other Enumerable
  def intersect(other)
    filter { |item| other.include?(item) }
  end

  alias :& :intersect

  # Returns a new Enumerable that iterates over the base Enumerable applying the transformer block to each item, e.g.:
  #   [1, 2, 3].transform_value { |n| n * 2 }.to_a #=> [2, 4, 6]
  #
  # Unlike Array.map, {#wrap} reflects changes to the base Enumerable, e.g.:
  #   a = [2, 4, 6]
``#   transformed = a.wrap { |n| n * 2 }
  #   a << 4
  #   transformed.to_a #=> [2, 4, 6, 8]
  #
  # In addition, transform has a small, fixed storage requirement, making it preferable to select for large collections.
  # Note, however, that unlike map, transform does not return an Array.
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
  
  # Sorts this collection's members with a partial sort operator, i.e. the comparison returns -1, 0, 1 or nil.
  # The resulting sorted order places each non-nil comparable items in the sort order. The order of nil
  # comparison items is indeterminate.
  #
  # @example
  #    [Array, Numeric, Enumerable, Set].partial_sort #=> [Array, Numeric, Set, Enumerable]
  # @return [Enumerable] the items in this collection in partial sort order
  def partial_sort
    unless block_given? then return partial_sort { |item1, item2| item1 <=> item2 } end
    sort { |item1, item2| yield(item1, item2) or 1 }
  end
  
  # Sorts this collection's members with a partial sort operator on the results of applying the block.
  #
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
