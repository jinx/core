module Jinx
  # CaseInsensitiveHash accesses entries in a case-insensitive String comparison. The accessor method
  # key argument is converted to a String before look-up.
  #
  # @example
  #   hash = CaseInsensitiveHash.new
  #   hash[:UP] = "down"
  #   hash['up'] #=> "down"
  class CaseInsensitiveHash < Hash
    def initialize
      super
    end

    def [](key)
      # if there is lower-case key association, then convert to lower-case and return.
      # otherwise, delegate to super with the call argument unchanged. this ensures
      # that a default block passed to the constructor will be called with the correct
      # key argument.
      has_key?(key) ? super(key.to_s.downcase) : super(key)
    end

    def []=(key, value)
      super(key.to_s.downcase, value)
    end

    def has_key?(key)
      super(key.to_s.downcase)
    end

    def delete(key)
      super(key.to_s.downcase)
    end

    alias :store :[]=
    alias :include? :has_key?
    alias :key? :has_key?
    alias :member? :has_key?
  end
end