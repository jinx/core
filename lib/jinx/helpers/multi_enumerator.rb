require 'jinx/helpers/collection'

module Jinx
  # A MultiEnumerator iterates over several Enumerators in sequence. Unlike Array#+, MultiEnumerator reflects changes to the
  # underlying enumerators.
  #
  # @example
  #   a = [1, 2]
  #   b = [4, 5]
  #   ab = MultiEnumerator.new(a, b)
  #   ab.to_a #=> [1, 2, 4, 5]
  #   a << 3; b << 6; ab.to_a #=> [1, 2, 3, 4, 5, 6]
  class MultiEnumerator
    include Collection

    # @return [<Enumerable>] the enumerated collections
    attr_reader :components, :appender

    # Initializes a new {MultiEnumerator} on the given components.
    #
    # @param [<Enumerable>] the component enumerators to compose
    # @yield [item] the optional appender block
    # @yieldparam item the item to append
    def initialize(*enums, &appender)
      super()
      @components = enums
      @components.compact!
      @appender = appender
    end

    # Iterates over each of this MultiEnumerator's enumerators in sequence.
    def each
      @components.each { |enum| enum.each { |item| yield item  } }
    end
    
    # @param item the item to append
    # @raise [NoSuchMethodError] if this {MultiEnumerator} does not have an appender
    def <<(item)
      @appender ? @appender << item : super
    end
      
    # Returns the union of the results of calling the given method symbol on each component.
    def method_missing(symbol, *args)
      self.class.new(@components.map { |enum|enum.send(symbol, *args) })
    end
  end
end