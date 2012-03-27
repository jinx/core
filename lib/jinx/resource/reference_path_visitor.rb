require 'jinx/helpers/collections'

require 'jinx/helpers/validation'
require 'jinx/helpers/visitor'
require 'jinx/helpers/math'

module Jinx
  # A ReferencePathVisitor traverses an attribute path.
  #
  # For example, given the attributes:
  #   favorites : Person -> Book
  #   authors : Book -> Author
  #   publications : Author -> Book
  # then a path visitor given by:
  #   ReferencePathVisitor.new(Person, [:favorites, :authors, :publications])
  # visits the transitive closure of books published by the authors of a person's favorite books.
  class ReferencePathVisitor < ReferenceVisitor
    # @return [ReferenceVisitor] a visitor which traverses the given path attributes starting at
    #   an instance of the given type
    #
    # @param [Class] the type of object to begin the traversal
    # @param [<Symbol>] the attributes to traverse
    # @param opts (see ReferenceVisitor#initialize)
    def initialize(klass, attributes, opts=nil)
      # augment the attributes path as a [class, attribute] path
      path = klass.property_path(*attributes)
      # make the visitor
      super(opts) do |ref|
        # Collect the path attributes whose type is the ref type up to the
        # next position in the path.
        max = lineage.size.min(path.size)
        pas = (0...max).map { |i| path[i].attribute if path[i].declarer === ref }
        pas.compact!
        ref.class.attribute_filter(pas)
      end
    end
  end
end