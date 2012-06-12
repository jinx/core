require 'singleton'
require 'jinx/helpers/lazy_hash'

module Jinx
  # A utility class to generate value qualifiers.
  class Uniquifier
    include Singleton

    # Returns a relatively unique integral qualifier. Successive calls to this method
    # within the same time zone spaced more than a millisecond apart return different
    # integers. Each generated qualifier is greater than the previous by an unspecified
    # amount.
    def self.qualifier
      # the first date that this method could be called
      @first ||= Date.new(2011, 12, 01)
      # days as integer + milliseconds as fraction since the first date
      diff = DateTime.now - @first
      # shift a tenth of a milli up into the integer portion
      decimillis = diff * 24 * 60 * 60 * 10000
      # truncate the fraction
      decimillis.truncate
    end

    def initialize
      @cache = Jinx::LazyHash.new { Hash.new }
    end
    
    # Returns a relatively unique String for the given base String object or
    # (object, String value) pair. In the former case, each call returns a distinct value.
    # In the latter case, successive calls of the same String value for the same object
    # class return the same unique value.
    #
    # This method is useful to transform a String object key to a unique value for testing
    # purposes.
    #
    # The unique value is comprised of a prefix and suffix. The prefix is the base value
    # with spaces replaced by an underscore. The suffix is a {Jinx::Uniquifier.qualifier}
    # converted to digits and lower-case letters, excluding the digits 0, 1 and characters
    # l, o to avoid confusion.
    #
    # @example
    #   Jinx::Uniquifier.instance.uniquify('Groucho') #=> Groucho_wiafye6e
    #   Jinx::Uniquifier.instance.uniquify('Groucho') #=> Groucho_uqafye6e
    #   Jinx::Uniquifier.instance.uniquify('Groucho Marx') #=> Groucho_ay23ye6e
    #   Jinx::Uniquifier.instance.uniquify(person, 'Groucho') #=> Groucho_wy874e6e
    #   Jinx::Uniquifier.instance.uniquify(person, 'Groucho') #=> Groucho_wy87ye6e
    #
    # @param obj the object containing the value to uniquify
    # @param value [String, nil] the value to make unique, or nil if the containing object is a String
    # @return [String, nil] the new unique value, or nil if the containing object is a String
    #   and the given value is nil
    def uniquify(obj, value=nil)
      if String === obj then
        to_unique(obj)
      elsif value then
        @cache[obj.class][value] ||= to_unique(value)
      end
    end

    def clear
      @cache.clear
    end
    
    private
    
    CHARS = 'abcdefghijkmnpqrstuvwxyz23456789'
    
    # @param value [String, nil] the value to make unique
    # @return [String] the new unique value, or nil if the given value is nil
    # @raise [ArgumentError] if value is neither a String nor nil
    def to_unique(value)
      return if value.nil?
      raise ArgumentError.new("#{value.qp} is not a String") unless String === value
      s = ''
      n = Jinx::Uniquifier.qualifier
      while n > 0 do
        n, m = n.divmod(32)
        s << CHARS[m]
      end
      [value.gsub(' ', '_'), s].join('_')
    end
  end
end
