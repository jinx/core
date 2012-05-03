require 'jinx/helpers/collection'
require 'jinx/helpers/hashable'

module Jinx
  # Hashable is a Hash mixin that adds utility methods to a Hash.
  # Hashable can be included by any class or module which implements an _each_ method
  # with arguments _key_ and _value_.
  module Hashable
    include Collection

    # @see Hash#each_pair
    def each_pair(&block)
      each(&block)
    end

    # @see Hash#[]
    def [](key)
      detect_value { |k, v| v if k == key }
    end

    # @see Hash#each_key
    def each_key
      each { |k, v| yield k }
    end

    # @yield [key] the detector block
    # @yieldparam key the hash key
    # @return the key for which the detector block returns a non-nil, non-false value,
    #   or nil if none
    # @example
    #   {1 => :a, 2 => :b, 3 => :c}.detect_key { |k| k > 1 } #=> 2
    def detect_key
      each_key { |k| return k if yield k }
      nil
    end
    
    def has_key?(key)
      !!detect_key { |k| k == key }
    end

    # @yield [value] the detector block
    # @yieldparam value the hash value
    # @return the key for which the detector block returns a non-nil, non-false value,
    #   or nil if none
    # @example
    #   {:a => 1, :b => 2, :c => 3}.detect_key_with_value { |v| v > 1 } #=> :b
    def detect_key_with_value
      each { |k, v| return k if yield v }
      nil
    end

    # @see Hash#each_value
    def each_value
      each { |k, v| yield v }
    end
    
    # Returns a Hashable which composes each value in this Hashable with the key of
    # the other Hashable, e.g.:
    #   x = {:a => :c, :b => :d}
    #   y = {:c => 1}
    #   z = x.compose(y)
    #   z[:a] #=> {:c => 1}
    #   z[:b] #=> nil
    #
    # The accessor reflects changes to the underlying hashes, e.g. given the above example:
    #   x[:b] = 2
    #   z[:b] #=> {:c => 1}
    #
    # Update operations on the result are not supported.
    #
    # @param [Hashable] other the Hashable to compose with this Hashable
    # @return [Hashable] the composed result
    def compose(other)
      transform_value { |v| {v => other[v]} if other.has_key?(v) }
    end

    # Returns a Hashable which joins each value in this Hashable with the key of
    # the other Hashable, e.g.:
    #   x = {:a => :c, :b => :d}
    #   y = {:c => 1}
    #   z = x.join(y)
    #   z[:a] #=> 1
    #   z[:b] #=> nil
    #
    # The accessor reflects changes to the underlying hashes, e.g. given the above example:
    #   x[:b] = 2
    #   z[:b] #=> 2
    #
    # Update operations on the result are not supported.
    #
    # @param [Hashable] other the Hashable to join with this Hashable
    # @return [Hashable] the joined result
    def join(other)
      transform_value { |v| other[v] }
    end

    # Returns a Hashable which associates each key of both this Hashable and the other Hashable
    # with the corresponding value in the first Hashable which has that key, e.g.:
    #   x = {:a => 1, :b => 2}
    #   y = {:b => 3, :c => 4}
    #   z = x + y
    #   z[:b] #=> 2
    #
    # The accessor reflects changes to the underlying hashes, e.g. given the above example:
    #   x.delete(:b)
    #   z[:b] #=> 3
    #
    # Update operations on the result are not supported.
    #
    # @param [Hashable] other the Hashable to form a union with this Hashable
    # @return [Hashable] the union result
    def union(other)
      MultiHash.new(self, other)
    end

    alias :+ :union

    # Returns a new Hashable that iterates over the base Hashable <key, value> pairs for which the block
    # given to this method evaluates to a non-nil, non-false value, e.g.:
    #   {:a => 1, :b => 2, :c => 3}.filter { |k, v| k != :b }.to_hash #=> {:a => 1, :c => 3}
    #
    # The default filter block tests the value, e.g.:
    #   {:a => 1, :b => nil}.filter.to_hash #=> {:a => 1}
    #
    # @yield [key, value] the filter block
    # @return [Hashable] the filtered result
    def filter(&block)
      Filter.new(self, &block)
    end

    # Optimization of {#filter} for a block that only uses the key.
    #
    # @example
    #   {:a => 1, :b => 2, :c => 3}.filter_on_key { |k| k != :b }.to_hash #=> {:a => 1, :c => 3}
    #
    # @yield [key] the filter block
    # @yieldparam key the hash key to filter
    # @return [Hashable] the filtered result
    def filter_on_key(&block)
      KeyFilter.new(self, &block)
    end

    # @return [Hashable] a {#filter} that only uses the value.
    # @yield [value] the filter block
    # @yieldparam value the hash value to filter
    # @return [Hashable] the filtered result
    def filter_on_value
      filter { |k, v| yield v }
    end

    # @return [Hash] a {#filter} of this Hashable which excludes the entries with a null value
    def compact
      filter_on_value { |v| not v.nil? }
    end

    # Returns the difference between this Hashable and the other Hashable in a Hash of the form:
    #
    # _key_ => [_mine_, _theirs_]
    #
    # where:
    # * _key_ is the key of association which differs
    # * _mine_ is the value for _key_ in this hash 
    # * _theirs_ is the value for _key_ in the other hash 
    #
    # @param [Hashable] other the Hashable to subtract
    # @yield [key, v1, v2] the optional block which determines whether values differ (default is equality)
    # @yieldparam key the key for which values are compared
    # @yieldparam v1 the value for key from this Hashable
    # @yieldparam v2 the value for key from the other Hashable
    # @return [{Object => (Object,Object)}] a hash of the differences
    def diff(other)
      (keys.to_set + other.keys).to_compact_hash do |k|
         mine = self[k]
         yours = other[k]
         [mine, yours] unless block_given? ? yield(k, mine, yours) : mine == yours
      end
    end

    # @yield [key1, key2] the key sort block
    # @return [Hashable] a hash whose #each and {#each_pair} enumerations are sorted by key
    def sort(&sorter)
      SortedHash.new(self, &sorter)
    end

    # Returns a hash which associates each key in this hash with the value mapped by the others.
    #
    # @example
    #   {:a => 1, :b => 2}.assoc_values({:a => 3, :c => 4}) #=> {:a => [1, 3], :b => [2, nil], :c => [nil, 4]}
    #   {:a => 1, :b => 2}.assoc_values({:a => 3}, {:a => 4, :b => 5}) #=> {:a => [1, 3, 4], :b => [2, nil, 5]}
    #
    # @param [<Hashable>] others the other Hashables to associate with this Hashable
    # @return [Hash] the association hash
    def assoc_values(*others)
      all_keys = keys
      others.each { |hash| all_keys.concat(hash.keys) }
      all_keys.to_compact_hash do |k|
        others.map { |other| other[k] }.unshift(self[k])
      end
    end

    # Returns an Enumerable whose each block is called on each key which maps to a value which
    # either equals the given target_value or satisfies the filter block.
    #
    # @param target_value the filter value
    # @yield [value] the filter block
    # @return [Enumerable] the filtered keys
    def enum_keys_with_value(target_value=nil, &filter) # :yields: value
      return enum_keys_with_value { |v| v == target_value } if target_value
      filter_on_value(&filter).keys
    end

    # @return [Enumerable] Enumerable over this Hashable's keys
    def enum_keys
      Enumerable::Enumerator.new(self, :each_key)
    end

    # @return [Array] this Hashable's keys
    def keys
      enum_keys.to_a
    end

    # @param key search target
    # @return [Boolean] whether this Hashable has the given key
    def has_key?(key)
      enum_keys.include?(key)
    end

    alias :include? :has_key?

    # @return [Enumerable] an Enumerable over this Hashable's values
    def enum_values
      Enumerable::Enumerator.new(self, :each_value)
    end

    # @yield [key] the key selector
    # @return [Enumerable] the keys which satisfy the block given to this method
    def select_keys(&block)
      enum_keys.select(&block)
    end

    # @yield [key] the key rejector
    # @return [Enumerable] the keys which do not satisfy the block given to this method
    def reject_keys(&block)
      enum_keys.reject(&block)
    end

    # @yield [value] the value selector
    # @return [Enumerable] the values which satisfy the block given to this method
    def select_values(&block)
      enum_values.select(&block)
    end

    # @yield [value] the value rejector
    # @return [Enumerable] the values which do not satisfy the block given to this method
    def reject_values(&block)
      enum_values.reject(&block)
    end

    # @return [Array] this Enumerable's values
    def values
      enum_values.to_a
    end

    # @param value search target
    # @return [Boolean] whether this Hashable has the given value
    def has_value?(value)
      enum_values.include?(value)
    end

    # @return [Array] a flattened Array of this Hash
    # @example
    #   {:a => {:b => :c}, :d => :e, :f => [:g]} #=> [:a, :b, :c, :d, :e, :f, :g]
    def flatten
      Flattener.new(self).to_a
    end

    # @yield [key, value] hash splitter
    # @return [(Hash, Hash)] two hashes split by whether calling the block on the
    #   entry returns a non-nil, non-false value
    # @example
    #   {:a => 1, :b => 2}.split { |k, v| v < 2 } #=> [{:a => 1}, {:b => 2}]
    def split(&block)
      partition(&block).map { |pairs| pairs.to_assoc_hash }
    end

    # Returns a new Hash that recursively copies this hash's values. Values of type hash are copied using copy_recursive.
    # Other values are unchanged.
    #
    # This method is useful for preserving and restoring hash associations.
    #
    # @return [Hash] a deep copy of this Hashable 
    def copy_recursive
      copy = Hash.new
      keys.each do |k|
        value = self[k]
        copy[k] = Hash === value ? value.copy_recursive : value
      end
      copy
    end

    # @example
    #   {:a => 1, :b => 2}.transform_value { |n| n * 2 }.values #=> [2, 4] 
    #                                           
    # @yield [value] transforms the given value
    # @yieldparam [value] the value to transform 
    # @return [Hash] a new Hash that transforms each value
    def transform_value(&transformer)
      ValueTransformerHash.new(self, &transformer)
    end

    # @example
    #   {1 => :a, 2 => :b}.transform_key { |n| n * 2 }.keys #=> [2, 4]
    #                                           
    # @yield [key] transforms the given key
    # @yieldparam [value] the key to transform 
    # @return [Hash] a new Hash that transforms each key
    def transform_key(&transformer)
      KeyTransformerHash.new(self, &transformer)
    end
    
    # @return [Hash] a new Hash created from this Hashable's content
    def to_hash
      hash = {}
      each { |k, v| hash[k] = v }
      hash
    end

    def to_set
      to_a.to_set
    end

    def to_s
      to_hash.to_s
    end

    def inspect
      to_hash.inspect
    end

    def ==(other)
      to_hash == other.to_hash rescue super
    end

    private

    # @see #filter
    class Filter
      include Hashable

      def initialize(base, &filter)
        @base = base
        @filter = filter
      end

      def each
        @base.each { |k, v| yield(k, v) if @filter ? @filter.call(k, v) : v }
      end
    end

    # @see #filter_on_key
    class KeyFilter < Filter
      include Hashable

      def initialize(base)
        super(base) { |k, v| yield(k) }
      end

      def [](key)
        super if @filter.call(key, nil)
      end
    end

    # @see #sort
    class SortedHash
      include Hashable

      def initialize(base, &comparator)
        @base = base
        @comparator = comparator
      end

      def each
        @base.keys.sort { |k1, k2| @comparator ? @comparator.call(k1, k2) : k1 <=> k2 }.each { |k| yield(k, @base[k]) }
      end
    end

    # Combines hashes. See Hash#+ for details.
    class MultiHash
      include Hashable

      # @return [<Hashable>] the enumerated hashes
      attr_reader :components

      def initialize(*hashes)
        if hashes.include?(nil) then raise ArgumentError.new("MultiHash is missing a component hash.") end
        @components = hashes
      end

      def [](key)
        @components.each { |hash| return hash[key] if hash.has_key?(key) }
        nil
      end

      def has_key?(key)
        @components.any? { |hash| hash.has_key?(key) }
      end

      def has_value?(value)
        @components.any? { |hash| hash.has_value?(value) }
      end

      def each
        @components.each_with_index do |hash, index|
          hash.each do |k, v|
             yield(k, v) unless (0...index).any? { |i| @components[i].has_key?(k) }
          end
        end
        self
      end
    end
  end
  
  # The ValueTransformerHash class pipes the value from a base Hashable into a transformer block.
  # @private
  class ValueTransformerHash
    include Hashable

    # Creates a ValueTransformerHash on the base hash and value transformer block.
    #
    # @param [Hash, nil] base the hash to transform
    # @yield [value] transforms the base value
    # @yieldparam value the base value to transform
    def initialize(base, &transformer)
      @base = base
      @xfm = transformer
    end
                                         
    # @param key the hash key
    # @return the value at key after this ValueTransformerHash's transformer block is applied, or nil
    #   if this hash does not contain key
    def [](key)
      @xfm.call(@base[key]) if @base.has_key?(key)
    end
    
    # @yield [key, value] operate on the key and transformed value
    # @yieldparam key the hash key
    # @yieldparam value the transformed hash value
    def each
      @base.each { |k, v| yield(k, @xfm.call(v)) }
    end
  end
  
  # The KeyTransformerHash class pipes the key from a base Hashable into a transformer block.
  # @private
  class KeyTransformerHash
    include Hashable

    # Creates a KeyTransformerHash on the base hash and key transformer block.
    #
    # @param [Hash, nil] base the hash to transform
    # @yield [key] transforms the base key
    # @yieldparam key the base key to transform
    def initialize(base, &transformer)
      @base = base
      @xfm = transformer
    end

    # @param key the untransformed hash key
    # @return the value for the transformed key
    def [](key)
      @base[@xfm.call(@base[key])]
    end

    # @yield [key, value] operate on the transformed key and value
    # @yieldparam key the transformed hash key
    # @yieldparam value the hash value
    def each
      @base.each { |k, v| yield(@xfm.call(k), v) }
    end
  end
  
  # Hashinator creates a Hashable from an Enumerable on [_key_, _value_] pairs.
  # The Hashinator reflects changes to the underlying Enumerable.
  #
  # @example
  #   base = [[:a, 1], [:b, 2]]
  #   hash = Hashinator.new(base)
  #   hash[:a] #=> 1
  #   base.first[1] = 3
  #   hash[:a] #=> 3
  class Hashinator
    include Hashable

    def initialize(enum)
      @base = enum
    end

    def each
      @base.each { |pair| yield(*pair) }
    end
  end
end
