# This file loads the definitions of useful collection mix-ins and utility classes.
require 'set'
require 'enumerator'
require 'jinx/helpers/collection'
require 'jinx/helpers/array'
require 'jinx/helpers/hasher'
require 'jinx/helpers/hash'
require 'jinx/helpers/set'
require 'jinx/helpers/enumerate'
require 'jinx/helpers/filter'
require 'jinx/helpers/transformer'
require 'jinx/helpers/flattener'
require 'jinx/helpers/multi_enumerator'
require 'jinx/helpers/hasher'

class Object
  # @return [Boolean] whether this object is a {Jinx::Collection}
  def collection?
    Jinx::Collection === self
  end
end

### Extend common non-String Enumerable classes and interfaces with Jinx::Collection. ###

class Enumerable::Enumerator
  include Jinx::Collection
end

class Array
  include Jinx::Collection
end

class Set
  include Jinx::Collection
end

class File
  include Jinx::Collection
end

module Java::JavaUtil::Collection
  include Jinx::Collection
end
