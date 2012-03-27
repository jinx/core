module Jinx
  # The Collector utility implements the {on} method to apply a block to a collection
  # transitive closure.
  module Collector
    # Collects the result of applying the given block to the given obj.
    # If obj is a collection, then collects the result of recursively calling this
    # Collector on the enumerated members.
    # If obj is nil, then returns nil.
    # Otherwise, calls block on obj and returns the result.
    #
    # @example
    #  Collector.on([1, 2, [3, 4]]) { |n| n * 2 } #=> [2, 4, [6, 8]]]
    #  Collector.on(nil) { |n| n * 2 } #=> nil
    #  Collector.on(1) { |n| n * 2 } #=> 2
    # @param obj the collection or item to enumerate
    def self.on(obj, &block)
      obj.collection? ? obj.map { |item| on(item, &block) } : yield(obj) unless obj.nil?
    end
  end
end