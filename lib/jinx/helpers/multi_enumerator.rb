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
    attr_reader :components

    # Initializes a new {MultiEnumerator} on the given components.
    #
    # @param [<Enumerable>] the component enumerators to compose
    def initialize(*enums)
      super()
      @components = enums
      @components.compact!
    end

    # Iterates over each of this MultiEnumerator's Enumerators in sequence.
    def each
      @components.each { |enum| enum.each { |item| yield item  } }
    end
  end
end