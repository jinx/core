require 'jinx/helpers/collection'

module Jinx
  # This Transformer helper class applies a transformer block to a base enumeration.
  class Transformer
    include Enumerable, Collection

    def initialize(enum=[], &transformer)
      @base = enum
      @xfm = transformer
    end

    # Sets the base Enumerable on which this Transformer operates and returns this transformer, e.g.:
    #  transformer = Transformer.new { |n| n * 2 }
    #  transformer.on([1, 2, 3]).to_a #=> [2, 4, 6]
    def on(enum)
      @base = enum
      self
    end

    # Calls the block on each item after this Transformer's transformer block is applied.
    def each
      @base.each { |item| yield(item.nil? ? nil : @xfm.call(item)) }
    end
  end
end