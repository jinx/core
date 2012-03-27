require 'jinx/helpers/hashable'

module Jinx
  # The KeyTransformerHash class pipes the key access argument into a transformer block before
  # accessing a base Hashable, e.g.:
  #   hash = KeyTransformerHash.new { |key| key % 2 }
  #   hash[1] = :a
  #   hash[3] #=> :a
  class KeyTransformerHash
    include Hashable

    # Creates a KeyTransformerHash on the optional base hash and required key transformer block.
    #
    # @param [Hash, nil] base the hash to transform
    # @yield [key] transforms the base key
    # @yieldparam key the base key to transform
    def initialize(base={}, &transformer)
      @base = base
      @xfm = transformer
    end

    # Returns the value at key after this KeyTransformerHash's transformer block is applied to the key,
    # or nil if the base hash does not contain an association for the transformed key.
    def [](key)
      @base[@xfm.call(key)]
    end

    # Sets the value at key after this KeyTransformerHash's transformer block is applied, or nil
    # if this hash does not contain an association for the transformed key.
    def []=(key, value)
      @base[@xfm.call(key)] = value
    end

    # Delegates to the base hash.
    # Note that this breaks the standard Hash contract, since
    #   all? { |k, v| self[k] }
    # is not necessarily true because the key is transformed on access.
    # @see Accessor for a KeyTransformerHash variant that restores this contract
    def each(&block)
      @base.each(&block)
    end
  end
end