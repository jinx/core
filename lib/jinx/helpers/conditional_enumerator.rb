module Jinx
  # ConditionalEnumerator applies a filter to another Enumerable.
  #
  # @example
  #   ConditionalEnumerator.new([1, 2, 3]) { |i| i < 3 }.to_a #=> [1, 2]
  class ConditionalEnumerator
    include Collection

    # Creates a ConditionalEnumerator which wraps the base Enumerator with a conditional filter.
    def initialize(base, &filter)
      @base = base
      @filter = filter
    end

    # Applies the iterator block to each of this ConditionalEnumerator's base Enumerable items
    # for which this ConditionalEnumerator's filter returns true.
    def each
      @base.each { |item| (yield item) if @filter.call(item) }
    end
  end
end