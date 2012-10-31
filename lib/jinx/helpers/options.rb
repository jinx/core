require 'jinx/helpers/collections'

require 'jinx/helpers/validation'
require 'jinx/helpers/merge'

# Options is a utility class to support a method option parameter.
# Option argument parsing is described in {Options.get}.
class Options
  # Returns the value of option in options as follows:
  # * If options is a hash which contains the option key, then this method returns
  #   the option value. A non-collection options[option] value is wrapped as a singleton
  #   collection to conform to a collection default type, as shown in the example below.
  # * If options equals the option symbol, then this method returns +true+.
  # * If options is an Array of symbols which includes the given option, then this method
  #   returns +true+.
  # * Otherwise, this method returns the default.
  #
  # If default is nil and a block is given to this method, then the default is determined
  # by calling the block with no arguments. The block can also be used to raise a missing
  # option exception, e.g.:
  #   Options.get(:userid, options) { raise RuntimeError.new("Missing required option: userid") }
  #
  # @example
  #   Options.get(:create, {:create => true}) #=> true
  #   Options.get(:create, :create) #=> true
  #   Options.get(:create, [:create, :compress]) #=> true
  #   Options.get(:create, nil) #=> nil
  #   Options.get(:create, nil, :false) #=> false
  #   Options.get(:create, nil, :true) #=> true
  #   Options.get(:values, nil, []) #=> []
  #   Options.get(:values, {:values => :a}, []) #=> [:a]
  #   Options.get(:values, [:create, {:values => :a}], []) #=> [:a]
  def self.get(option, options, default=nil, &block)
    return default(default, &block) if options.nil?
    case options
      when Hash then
        value = options[option]
        if String === value then value.strip! end
        value.nil_or_empty? ? default(default, &block) : value
      when Enumerable then
        detect_in_enumerable(option, options) or default(default, &block)
      when Symbol then
        option == options or default(default, &block)
      else
        raise ArgumentError.new("Options argument type is not supported; expected Hash or Symbol, found: #{options.class}")
    end
  end

  # Returns the given option list as a hash, determined as follows:
  # * If an item is a hash, then that hash is included in the result
  # * If an item is a symbol _s_, then {_s_ => true} is included in the result
  #
  # @example
  #   Options.to_hash() #=> {}
  #   Options.to_hash(nil) #=> {}
  #   Options.to_hash(:a => 1) #=> {:a => 1}
  #   Options.to_hash(:a) #=> {:a => true}
  #   Options.to_hash(:a, :b => 2) #=> {:a => true, :b => 2}
  # @param [<[Symbol, Hash]>] opts the option list
  # @return [Hash] the option hash
  def self.to_hash(*opts)
    hash = {}
    opts.compact!
    opts.each do |opt|
      case opt
        when Symbol then hash[opt] = true
        when Hash then hash.merge!(opt)
        else raise ArgumentError.new("Expected a symbol or hash option, found #{opt.qp}")
      end
    end
    hash
  end

  # @param [Hash, Symbol, nil] opts the options to validate
  # @raise [ValidationError] if the given options are not in the given allowable choices
  def self.validate(options, choices)
    to_hash(options).each_key do |opt|
      raise ValidationError.new("Option is not supported: #{opt}") unless choices.include?(opt)
    end
  end

  private
  
  def self.detect_in_enumerable(key, opts)
    opts.detect_value do |opt|
      Hash === opt ? opt[key] : opt == key
    end
  end

  def self.default(value)
    value.nil? && block_given? ? yield : value
  end
end