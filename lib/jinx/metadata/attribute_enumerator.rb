module Jinx
  # A filter on the standard attribute symbol => metadata hash that yields
  # each attribute which satisfies the attribute metadata condition.
  class AttributeEnumerator
    include Enumerable

    # @param [{Symbol => Property}] hash the attribute symbol => metadata hash
    # @yield [prop] optional condition which determines whether the attribute is
    #   selected (default is all attributes)
    # @yieldparam [Property] the metadata for the standard attribute
    # @raise [ArgumentError] if a parameter is missing 
    def initialize(hash, &filter)
      Jinx.fail(ArgumentError, "Attribute filter missing hash argument") if hash.nil?
      @hash = hash
      @filter = block_given? ? filter : Proc.new { true }
    end

    # @yield [attribute, prop] the block to apply to the filtered attribute metadata and attribute
    # @yieldparam [Symbol] attribute the attribute
    # @yieldparam [Property] prop the attribute metadata
    def each_pair
      @hash.each { |pa, prop| yield(pa, prop) if @filter.call(prop) }
    end
    
    # @return [<(Symbol, Property)>] the (symbol, attribute) enumerator
    def enum_pairs
      enum_for(:each_pair)
    end
    
    # @yield [attribute] block to apply to each filtered attribute
    # @yieldparam [Symbol] the attribute which satisfies the filter condition
    def each_attribute(&block)
      each_pair { |pa, prop| yield(pa) }
    end
    
    alias :each :each_attribute

    # @yield [prop] the block to apply to the filtered attribute metadata
    # @yieldparam [Property] prop the attribute metadata
    def each_property
      each_pair { |pa, prop| yield(prop) }
    end
    
    # @return [<Property>] the property enumerator
    def properties
      @prop_enum ||= enum_for(:each_property)
    end
    
    # @yield [attribute] the block to apply to the attribute
    # @yieldparam [Symbol] attribute the attribute to detect
    # @return [Property] the first attribute metadata whose attribute satisfies the block
    def detect_property
      each_pair { |pa, prop| return prop if yield(pa) }
      nil
    end
    
    # @yield [prop] the block to apply to the attribute metadata
    # @yieldparam [Property] prop the attribute metadata
    # @return [Symbol] the first attribute whose metadata satisfies the block
    def detect_with_property
      each_pair { |pa, prop| return pa if yield(prop) }
      nil
    end

    # @yield [prop] the attribute selection filter
    # @yieldparam [Property] prop the candidate attribute metadata
    # @return [AttributeEnumerator] a new eumerator which applies the filter block given to this
    #   method with the Property enumerated by this enumerator
    def compose
      AttributeEnumerator.new(@hash) { |prop| @filter.call(prop) and yield(prop) }
    end
  end
end