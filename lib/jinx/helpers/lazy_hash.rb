require 'jinx/helpers/options'

module Jinx
  # A Hash that creates a new entry on demand.
  class LazyHash < Hash
    # Creates a new Hash with the specified value factory proc.
    # The factory proc has one argument, the key.
    # If access by key fails, then a new association is created
    # from the key to the result of calling the factory proc.
    #
    # Example:
    #   hash = LazyHash.new { |key| key.to_s }
    #   hash[1] = "1"
    #   hash[1] #=> "1"
    #   hash[2] #=> "2"
    #
    # If a block is not provided, then the default association value is nil, e.g.:
    #   hash = LazyHash.new
    #   hash.has_key?(1) #=> false
    #   hash[1] #=> nil
    #   hash.has_key?(1) #=> true
    #
    # A nil key always returns nil. There is no hash entry for nil, e.g.:
    #   hash = LazyHash.new { |key| key }
    #   hash[nil] #=> nil
    #   hash.has_key?(nil) #=> false
    #
    # If the :compact option is set, then an entry is not created
    # if the value initializer result is nil or empty, e.g.:
    #   hash = LazyHash.new { |n| 10.div(n) unless n.zero? }
    #   hash[0] #=> nil
    #   hash.has_key?(0) #=> false
    def initialize(options=nil)
      reject_flag = Options.get(:compact, options)
      # Make the hash with the factory block
      super() do |hash, key|
        if key then
          value = yield key if block_given?
          hash[key] = value unless reject_flag and value.nil_or_empty?
        end
      end
    end
  end
end
