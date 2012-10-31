module Jinx
  # A PartialOrder is a Comparable with restricted scope. Classes which include
  # PartialOrder are required to implement the <=> operator with the following
  # semantics:
  # *  If if a and b are comparable, then return the value of the comparison.
  # *  Otherwise, return nil.
  # A PartialOrder thus relaxes comparison symmetry, e.g.:
  #   a < b
  # does not imply:
  #   b >= a.
  #
  # @example
  #   module Queued
  #     attr_reader :queue
  #     def <=>(other)
  #       queue.index(self) <=> queue.index(other) if queue.equal?(other.queue)
  #     end
  #   end
  #   q1 = [a, b] # a, b are Queued
  #   q2 = [c]    # c is Queued
  #   a < b #=> true
  #   b < c #=> nil
  module PartialOrder
    include Comparable
  
    # Override the Comparable instance methods to accomodate comparisons which return nil.
    # Each method returns the following result:
    # * If the method argument is comparable to this object, then delegate to the standard
    #   Comparable method.
    # * Otherwise, return nil.
    Comparable.instance_methods(false).each do |m|
      define_method(m.to_sym) do |other|
         self <=> other ? super : nil
      end
    end
    
    # @return [Boolean] true if other is an instance of this object's class and other == self,
    #   false otherwise
    def eql?(other)
      self.class === other and super
    end

    alias :== :eql?
  end
end