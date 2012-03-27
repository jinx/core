require 'jinx/helpers/class'

class Array
  # The EMPTY_ARRAY constant is an immutable empty array, used primarily as a default argument.
  class << EMPTY_ARRAY = Array.new
    def <<(value)
      Jinx.fail(NotImplementedError, "Modification of the constant empty array is not supported")
    end
  end

  # Relaxes the Ruby Array methods which take an Array argument to allow collection Enumerable arguments.
  [:|, :+, :-, :&].each do |meth|
    redefine_method(meth) do |old_meth|
      lambda { |other| send(old_meth, other.collection? ? other.to_a : other) }
    end
  end

  redefine_method(:flatten) do |old_meth|
    # if an item is a non-Array collection, then convert it into an array before recursively flattening the list
    lambda { map { |item| item.collection? ? item.to_a : item }.send(old_meth) }
  end

  # Returns an array containing all but the first item in this Array. This method is syntactic sugar for
  # +self[1..-1]+ or +last(length-1)+.
  #
  # @return [Array] an array the tail of this array
  def rest
    self[1..-1]
  end

  alias :tail :rest

  # Deletes items from this array which do not satisfy the given block.
  #
  # @yield [item] the retention test
  # @yieldparam item an item in this array
  # @return [Array] this array
  def keep_if
    delete_if { |item| not yield(item) }
  end

  # Prints the content of this array as a series, e.g.:
  #   [1, 2, 3].to_series #=> "1, 2 and 3"
  #   [1, 2, 3].to_series('or') #=> "1, 2 or 3"
  #
  # If a block is given to this method, then the block is applied before the series is formed, e.g.:
  #   [1, 2, 3].to_series { |n| n + 1 } #=> "2, 3 and 4"
  def to_series(conjunction=nil)
    conjunction ||= 'and'
    return map { |item| yield item }.to_series(conjunction) if block_given?
    padded_conjunction = " #{conjunction} "
    # join all but the last item as a comma-separated list and append the conjunction and last item
    length < 2 ? to_s : self[0...-1].join(', ') + padded_conjunction + last.to_s
  end

  # Returns a new Hash generated from this array of arrays by associating the first element of each
  # member to the remaining elements. If there are only two elements in the member, then the first
  # element is associated with the second element. If there is less than two elements in the member,
  # the first element is associated with nil. An empty array is ignored.
  #
  # @example
  #   [[:a, 1], [:b, 2, 3], [:c], []].to_assoc_hash #=> { :a => 1, :b => [2,3], :c => nil }
  # @return [Hash] the first => rest hash
  def to_assoc_hash
    hash = {}
    each do |item|
      Jinx.fail(ArgumentError, "Array member must be an array: #{item.pp_s(:single_line)}") unless Array === item
      key = item.first
      if item.size < 2 then
        value = nil
      elsif item.size == 2 then
        value = item[1]
      else
        value = item[1..-1]
      end
      hash[key] = value unless key.nil?
    end
    hash
  end

  alias :base__flatten :flatten
  private :base__flatten
  # Recursively flattens this array, including any collection item that implements the +to_a+ method.
  def flatten
    # if any item is a Set or Java Collection, then convert those into arrays before recursively flattening the list
    if any? { |item| Set === item or Java::JavaUtil::Collection === item } then
      return map { |item| (Set === item or Java::JavaUtil::Collection === item) ? item.to_a : item }.flatten
    end
    base__flatten
  end

  # Concatenates the other Enumerable to this array.
  #
  # @param [#to_a] other the other Enumerable
  # @raise [ArgumentError] if other does not respond to the +to_a+ method
  def add_all(other)
    return concat(other) if Array === other
    begin
      add_all(other.to_a)
    rescue NoMethodError
      raise e
    rescue
      Jinx.fail(ArgumentError, "Can't convert #{other.class.name} to array")
    end
  end

  alias :merge! :add_all
end
