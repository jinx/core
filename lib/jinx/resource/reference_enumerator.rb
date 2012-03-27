require 'enumerator'
require 'generator'
require 'jinx/helpers/options'
require 'jinx/helpers/collections'

require 'jinx/helpers/validation'
require 'jinx/helpers/visitor'
require 'jinx/helpers/math'

module Jinx
  # A ReferenceEnumerator iterates over domain property references.
  class ReferenceEnumerator
    include Enumerable
    
    # @return [Resource] the domain object containing the references
    attr_reader :subject
    
    alias :on :subject
    
    alias :from :subject
    
    # @return [<Property>] the current property
    attr_reader :property
  
    # @param [Resource, nil] on the object containing the references
    # @param [<Property>, Property, nil] properties the property or properties to dereference
    def initialize(on=nil, properties=nil)
      @subject = on
      @properties = properties
    end
    
    # @param [Resource] obj the visiting domain object
    # @return [(Resource, Resource, Property)] the (visited, visiting, property) tuples
    # @yield [obj, from, property] operates on the visited domain object
    # @yieldparam [Resource] obj the visited domain object
    # @yieldparam [Resource] from the visiting domain object
    # @yieldparam [Property] property the visiting property
    def each
      return if @subject.nil?
      @properties.enumerate do |prop|
        @property = prop
        # the reference(s) to visit
        refs = @subject.send(prop.attribute)
        # associate each reference to visit with the current visited attribute
        refs.enumerate { |ref| yield(ref) }
      end
    end
  end
end