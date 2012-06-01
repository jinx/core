require 'jinx/helpers/options'
module Jinx
  # An Associative object implements a {#[]} method. 
  class Associative
    # @yield [key] the associated oject
    # @yieldparam key the key to find
    def initialize(&accessor)
      @accessor = accessor
    end
     
    # @param key the key to find
    # @return the associated object
    def [](key)
      @accessor.call(key)
    end

    # @yield [key] the associated oject
    # @yieldparam key the key to find
    # @return [Associative] a new Associative with a +[]=+ writer method 
    def writer(&writer)
      Writable.new(self, &writer)
    end
  end
  
  private
  
  class Writable < Associative
    def initialize(base, &writer)
      @base = base
      @writer = writer
    end
    
    def [](key)
      @base[key]
    end
    
    def []=(key, value)
      @writer.call(key, value)
    end
  end
end