require 'enumerator'
require 'generator'
require 'jinx/helpers/options'
require 'jinx/helpers/collections'

require 'jinx/helpers/validation'
require 'jinx/helpers/visitor'
require 'jinx/helpers/math'

module Jinx
  # A ReferenceVisitor traverses reference attributes.
  class ReferenceVisitor < Visitor
    # Creates a new ReferenceVisitor on domain reference attributes.
    #
    # The required selector block given to this initializer determines which attributes to
    # visit. The references to visit next thus consist of the current domain object's selector
    # attributes' values. If the :filter option is set, then the given filter block is applied
    # to the selected attribute references to restrict which domain objects will be visited.
    #
    # @param opts (see Visitor#initialize)
    # @option opts [Proc] :filter an optional filter on the references to visit
    # @yield [obj] returns the {AttributeEnumerator} of attributes to visit next from the
    #   current domain object
    # @yieldparam [Resource] obj the current domain object
    def initialize(opts=nil, &selector)
      Jinx.fail(ArgumentError, "Reference visitor missing domain reference selector") unless block_given?
      # the property selector
      @flt_sel = selector
      # the reference filter
      flt = Options.get(:filter, opts)
      # Initialize the Visitor with a reference enumerator which selects the reference
      # attributes and applies the optional filter if necessary.
      @ref_enums = {}
      super do |ref|
        # the reference property filter
        attrs = attributes_to_visit(ref)
        if attrs then
          logger.debug { "#{qp} visiting #{ref} attributes #{attrs.pp_s(:single_line)}..." } if @verbose
          # an enumerator on the reference properties
          enum = ReferenceEnumerator.new(ref, attrs.properties)
          # If there is a reference filter, then apply it to the enum references.
          flt ? enum.filter(&flt) : enum
        end
      end
    end
    
    private
    
    # @param [Resource] obj the visiting object
    # @return [Properties::Filter] the attributes to visit
    def attributes_to_visit(obj)
      @flt_sel.call(obj)
    end
  end
end