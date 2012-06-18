require 'jinx/helpers/uid'

module Jinx
  # A mix-in to convert a String to a unique value.
  module StringUniquifier
    # Returns a relatively unique String for the given base String. Each call returns
    # a distinct value.
    #
    # This method is useful to transform a String object key to a unique value for
    # testing purposes.
    #
    # The unique value is comprised of a prefix and suffix. The prefix is the base value
    # with spaces replaced by an underscore. The suffix is given by a {Jinx::UID.generate}
    # qualifier converted to digits and lower-case letters, excluding the digits 0, 1 and
    # the characters l, o to avoid confusion.
    #
    # @example
    #   Jinx::StringUniquifier.uniquify('Groucho') #=> Groucho_wiafye6e
    #
    # @param value [String] the value to make unique
    # @return [String, nil] the new unique value
    # @raise [ArgumentError] if value is not a String
    def self.uniquify(value)
      raise ArgumentError.new("#{value.qp} is not a String") unless String === value
      s = ''
      n = UID.generate
      while n > 0 do
        n, m = n.divmod(32)
        s << CHARS[m]
      end
      [value.gsub(' ', '_'), s].join('_')
    end
    
    private

    # The qualifier character range.
    CHARS = 'abcdefghijkmnpqrstuvwxyz23456789'
  end
end
