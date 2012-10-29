module Jinx
  # A Flattener applies a given block to flattened collection content.
  class Flattener
    include Collection

    # Visits the enumerated items in the given object's flattened content.
    # The given block is called on the base itself if the base is neither nil nor a Enumerable.
    # If the base object is nil or empty, then this method is a no-op and returns nil.
    def self.on(obj, &block)
      obj.collection? ? obj.each { |item| on(item, &block) } : yield(obj) unless obj.nil?
    end

    # Initializes a new Flattener on the given object.
    #
    # @param obj the Enumerable or non-collection object
    def initialize(obj)
      @base = obj
    end

    # Calls the the given block on this Flattener's flattened content.
    # If the base object is a collection, then the block is called on the flattened content.
    # If the base object is nil, then this method is a no-op.
    # If the base object is neither nil nor a collection, then the block given to this method
    # is called on the base object itself.
    #
    # @example
    #   Flattener.new(nil).each { |n| print n } #=>
    #   Flattener.new(1).each { |n| print n } #=> 1
    #   Flattener.new([1, [2, 3]]).each { |n| print n } #=> 123
    def each(&block)
      Flattener.on(@base, &block)
    end
    
    def to_s
      to_a.to_s
    end
  end
end