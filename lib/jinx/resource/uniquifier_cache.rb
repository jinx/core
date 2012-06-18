require 'singleton'
require 'jinx/helpers/lazy_hash'
require 'jinx/helpers/string_uniquifier'

module Jinx
  # A utility class to cache key value qualifiers.
  class UniquifierCache
    include Singleton

    def initialize
      @cache = Jinx::LazyHash.new { Hash.new }
    end
    
    # Returns the unique value generated for the given object and value.
    # Successive calls to this method for domain objects of the same class
    # and a given value return the same result. 
    #
    # @example
    #   Jinx::UniquifierCache.instance.get(person, 'Groucho') #=> Groucho_wy874e6e
    #   Jinx::UniquifierCache.instance.get(person.copy, 'Groucho') #=> Groucho_wy87ye6e
    #
    # @param [Resource] obj the domain object containing the value
    # @param [String] value the value to make unique
    # @return [String] the unique value
    def get(obj, value)
      @cache[obj.class][value] ||= StringUniquifier.uniquify(value)
    end
    
    # Clears all cache entries.
    def clear
      @cache.clear
    end
  end
end
