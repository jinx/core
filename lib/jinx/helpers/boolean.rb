# Boolean marks the +true+ and +false+ primitive objects.
module Boolean; end

class TrueClass
  include Boolean
end

class FalseClass
  include Boolean
end

class String
  # Converts this string to a boolean as follows:
  # * +true+, +t+, +yes+, +y+ or 1 => true
  # * +false+, +f+, +no+, +n+ or 0 => false
  #
  # The comparison is case-insensitive.
  #
  # @return [Boolean] the boolean value
  # @raise [ArgumentError] if this string does not match a supported representation
  def to_boolean
    case self
    when /^(true|t|yes|y|1)$/i then true
    when /^(false|f|no|n|0)$/i then false
    else
      raise ArgumentError.new("String value cannot be converted to boolean: '#{self}'")
    end
  end
end

class Integer
  # Converts this integer to a boolean as follows:
  # 1 => true
  # 0 => false
  #
  # @return [Boolean] the boolean value
  # @raise [ArgumentError] if this string does not match a supported representation
  def to_boolean
    case self
    when 1 then true
    when 0 then false
    else
      raise ArgumentError.new("Integer value cannot be converted to Boolean: #{self}")
    end
  end
end
