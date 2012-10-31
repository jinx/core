require 'jinx/helpers/collection'

module Jinx
  # Hasher is a mix-in that adds utility methods to a Hash.
  # This Hasher module can be included by any class or module which implements an _each_
  # method with arguments _key_ and _value_.
  module Hasher
    include Enumerable, Collection

    # @see Hash#each_pair
    def each_pair(&block)
      each(&block)
    end

    # @see Hash#each_key
    def each_key
      each { |k, v| yield k }
    end

    # @example
    #   {1 => :a, 2 => :b, 3 => :c}.detect_key { |k| k > 1 } #=> 2
    #
    # @yield [key] the detector block
    # @yieldparam key the hash key
    # @return the hash key for which the detector block returns a non-nil, non-false result,
    #   or nil if none
    def detect_key
      each_key { |k| return k if yield k }
      nil
    end

    # @param key the search target
    # @return [Boolean] whether this Hasher has the given key
    def has_key?(key)
      each_key { |k| return true if k.eql?(key) }
      false
    end

    alias :include? :has_key?

    # @see {Enumerable#hash_value}
    # @example
    #   {1 => 2, 3 => 4}.detect_value { |k, v| v if k > 1 } #=> 4
    # @return (see Enumerable#hash_value)
    def detect_value
      each do |k, v|
        value = yield(k, v)
        return value if value
      end
      nil
    end

    # @example
    #   {:a => 1, :b => 2, :c => 3}.detect_key_with_value { |v| v > 1 } #=> :b
    #
    # @yield [value] the detector block
    # @yieldparam value the hash value
    # @return the key for which the detector block returns a non-nil, non-false value,
    #   or nil if none
    def detect_key_with_value
      each { |k, v| return k if yield v }
      nil
    end

    # @see Hash#each_value
    def each_value
      each { |k, v| yield v }
    end

    # @example
    #   {:a => 1, :b => 2}.detect_hash_value { |v| v > 1 } #=> 2
    #
    # @yield [value] the detector block
    # @yieldparam value the hash value
    # @return a hash value for which the detector block returns a non-nil, non-false result,
    #   or nil if none
    def detect_hash_value
      each_value { |v| return v if yield v }
      nil
    end

    # @see Hash#[]
    def [](key)
      detect_value { |k, v| v if k.eql?(key) }
    end
    
    # Returns a Hasher which composes each value in this Hasher with the key of the
    # other Hasher, e.g.:
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
    # @param [Hasher] other the Hasher to compose with this Hasher
    # @return [Hasher] the composed result
    def compose(other)
      transform_value { |v| {v => other[v]} if other.has_key?(v) }
    end

    # Returns a Hasher which joins each value in this Hasher with the key of the
    # other Hasher, e.g.:
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
    # @param [Hasher] other the Hasher to join with this Hasher
    # @return [Hasher] the joined result
    def join(other)
      transform_value { |v| other[v] }
    end

    # Returns a Hasher which associates each key of both this Hasher and the other
    # Hasher with the corresponding value in the first Hasher which has that key, e.g.:
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
    # @param [Hasher] other the Hasher to form a union with this Hasher
    # @return [Hasher] the union result
    def union(other)
      MultiHash.new(self, other)
    end

    alias :+ :union

    # Returns a new Hasher that iterates over the base Hasher <key, value> pairs for which
    # the block given to this method evaluates to a non-nil, non-false value, e.g.:
    #   {:a => 1, :b => 2, :c => 3}.filter { |k, v| k != :b }.to_hash #=> {:a => 1, :c => 3}
    #
    # The default filter block tests the value, e.g.:
    #   {:a => 1, :b => nil}.filter.to_hash #=> {:a => 1}
    #
    # @yield [key, value] the filter block
    # @return [Hasher] the filtered result
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
    # @return [Hasher] the filtered result
    def filter_on_key(&block)
      KeyFilter.new(self, &block)
    end

    # @return [Hasher] a {#filter} that only uses the value.
    # @yield [value] the filter block
    # @yieldparam value the hash value to filter
    # @return [Hasher] the filtered result
    def filter_on_value
      filter { |k, v| yield v }
    end

    # @return [Hash] a {#filter} of this Hasher which excludes the entries with a null value
    def compact
      filter_on_value { |v| not v.nil? }
    end

    # Returns the difference between this Hasher and the other Hasher in a Hash of the form:
    #
    # _key_ => [_mine_, _theirs_]
    #
    # where:
    # * _key_ is the key of association which differs
    # * _mine_ is the value for _key_ in this hash 
    # * _theirs_ is the value for _key_ in the other hash 
    #
    # @param [Hasher] other the Hasher to subtract
    # @yield [key, v1, v2] the optional block which determines whether values differ (default is equality)
    # @yieldparam key the key for which values are compared
    # @yieldparam v1 the value for key from this Hasher
    # @yieldparam v2 the value for key from the other Hasher
    # @return [{Object => (Object,Object)}] a hash of the differences
    def difference(other)
      (keys.to_set + other.keys).to_compact_hash do |k|
         mine = self[k]
         yours = other[k]
         [mine, yours] unless block_given? ? yield(k, mine, yours) : mine == yours
      end
    end
    
    alias :diff :difference

    # @yield [key1, key2] the key sort block
    # @return [Hasher] a hash whose #each and {#each_pair} enumerations are sorted by key
    def sort(&sorter)
      SortedHash.new(self, &sorter)
    end

    # Returns a hash which associates each key in this hash with the value mapped by the others.
    #
    # @example
    #   {:a => 1, :b => 2}.assoc_values({:a => 3, :c => 4}) #=> {:a => [1, 3], :b => [2, nil], :c => [nil, 4]}
    #   {:a => 1, :b => 2}.assoc_values({:a => 3}, {:a => 4, :b => 5}) #=> {:a => [1, 3, 4], :b => [2, nil, 5]}
    #
    # @param [<Hasher>] others the other Hashers to associate with this Hasher
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

    # @return [Enumerable] Enumerable over this Hasher's keys
    def enum_keys
      Enumerable::Enumerator.new(self, :each_key)
    end

    # @return [Array] this Hasher's keys
    def keys
      enum_keys.to_a
    end

    # @return [Enumerable] an Enumerable over this Hasher's values
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
    # @return [Boolean] whether this Hasher has the given value
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
    # @return [Hash] a deep copy of this Hasher 
    def copy_recursive
      copy = Hash.new
      keys.each do |k|
        value = self[k]
        copy[k] = Hash === value ? value.copy_recursive : value
      end
      copy
    end

    # Returns a new Hasher which applies a transformer block to each value in this
    # base Hasher. The result reflects changes to this underlying base Hasher.
    #
    # @example
    #   h = {:a => 1, :b => 2}
    #   xfm = h.transform_value { |n| n * 2 }
    #   xfm.values #=> [2, 4]
    #   xfm[:a] #=> 2
    #   xfm[:b] #=> 4
    #   h[:c] = 3
    #   xfm[:c] #=> 6
    #                                           
    # @yield [value] transforms the given value
    # @yieldparam value the value to transform 
    # @return [Hasher] a new Hasher that transforms each value
    def transform_value(&transformer)
      ValueTransformerHash.new(self, &transformer)
    end

    # Returns a new Hasher which applies a transformer block to each key in this
    # base Hasher. The result reflects changes to this underlying base Hasher.
    #
    # @example
    #   h = {1 => :a, 2 => :b}
    #   xfm = h.transform_key { |n| n * 2 }
    #   xfm.keys #=> [2, 4]
    #   xfm[2] #=> :a
    #   xfm[3] #=> nil
    #   xfm[4] #=> :b
    #   h[3] = :c
    #   xfm[6] #=> :c
    #                                           
    # @yield [key] transforms the given key
    # @yieldparam key the key to transform 
    # @return [Hasher] a new Hasher that transforms each key
    def transform_key(&transformer)
      KeyTransformerHash.new(self, &transformer)
    end
    
    # @return [Hash] a new Hash created from this Hasher's content
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
      include Hasher

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
      include Hasher

      def initialize(base)
        super(base) { |k, v| yield(k) }
      end

      def [](key)
        super if @filter.call(key, nil)
      end
    end

    # @see #sort
    class SortedHash
      include Hasher

      def initialize(base, &comparator)
        @base = base
        @comparator = comparator
      end

      def each
        @base.keys.sort { |k1, k2| @comparator ? @comparator.call(k1, k2) : k1 <=> k2 }.each { |k| yield(k, @base[k]) }
      end
    end

    # Combines hashes. See {Hasher#union} for details.
    class MultiHash
      include Hasher

      # @return [<Hasher>] the enumerated hashes
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
      
      # Returns the union of the results of calling the given method symbol on each component.
      def method_missing(symbol, *args)
        @components.map { |hash| hash.send(symbol, *args) }.inject { |value, result| result.union(value) }
      end
    end
  end
  
  # The ValueTransformerHash class pipes the value from a base Hasher into a transformer block.
  # @private
  class ValueTransformerHash
    include Hasher

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
  
  # The KeyTransformerHash class applies a transformer block to each key in a base Hasher.
  # @private
  class KeyTransformerHash
    include Hasher

    # Creates a KeyTransformerHash on the base hash and key transformer block.
    #
    # @param [Hash] base the hash to transform
    # @yield [key] transforms the base key
    # @yieldparam key the base key to transform
    def initialize(base, &transformer)
      @base = base
      @xfm = transformer
    end

    # @yield [key, value] operate on the transformed key and value
    # @yieldparam key the transformed hash key
    # @yieldparam value the hash value
    def each
      @base.each { |k, v| yield(@xfm.call(k), v) }
    end
  end
  
  # Hashinator creates a Hasher from an Enumerable on [_key_, _value_] pairs.
  # The Hashinator reflects changes to the underlying Enumerable.
  #
  # @example
  #   base = [[:a, 1], [:b, 2]]
  #   hash = Hashinator.new(base)
  #   hash[:a] #=> 1
  #   base.first[1] = 3
  #   hash[:a] #=> 3
  class Hashinator
    include Hasher

    def initialize(enum)
      @base = enum
    end

    def each
      @base.each { |pair| yield(*pair) }
    end
  end
end
