require 'jinx/helpers/collections'

require 'jinx/helpers/options'

# Enumerator overwrites to_enum, so include it first
require 'enumerator'
require 'generator'

module Jinx
  # Error raised on a visit failure.
  class VisitError < RuntimeError; end
  
  # Visitor traverses items and applies an operation, e.g.:
  #   class Node
  #     attr_accessor :children, :value
  #     def initialize(value, parent=nil)
  #       @value = value
  #       @children = []
  #       @parent = parent
  #       @parent.children << self if @parent
  #     end
  #   end
  #   parent = Node.new(1)
  #   child = Node.new(2, parent)
  #   multiplier = 2
  #   Jinx::Visitor.new { |node| node.children }.visit(parent) { |node| node.value *= multiplier } #=> 2
  #   parent.value #=> 2
  #   child.value #=> 4
  #
  # The visit result is the result of evaluating the operation block on the initial visited node.
  # Visiting a collection returns an array of the result of visiting each member of the collection,
  # e.g. augmenting the preceding example:
  #   parent2 = Node.new(3)
  #   child2 = Node.new(4, parent2)
  #   Jinx::Visitor.new { |node| node.children }.visit([parent, parent2]) { |node| node.value *= multiplier } #=> [2, 6]
  # Each visit captures the visit result in the +visited+ hash, e.g.:
  #   parent = Node.new(1)
  #   child = Node.new(2, parent)
  #   visitor = Jinx::Visitor.new { |node| node.children }
  #   visitor.visit([parent]) { |node| node.value += 1 }
  #   parent.value #=> 2
  #   visitor.visited[parent] #=> 2
  #   child.value #=> 3
  #   visitor.visited[child] #=> 3
  #
  # A +return+ from the operation block terminates the visit and exits from the defining scope with the block return value,
  # e.g. given the preceding example:
  #   def increment(parent, limit)
  #     Jinx::Visitor.new { |node| node.children }.visit(parent) { |node| node.value < limit ? node.value += 1 : return }
  #   end
  #   increment(parent, 2) #=> nil
  #   parent.value #=> 2
  #   child.value #=> 2
  #
  # The to_enum method allows navigator iteration, e.g.:
  #   Jinx::Visitor.new { |node| node.children }.to_enum(parent).detect { |node| node.value == 2 }
  class Visitor
  
    attr_reader :options, :visited, :lineage, :cycles
  
    # Creates a new Visitor which traverses the child objects returned by the navigator block.
    # The navigator block takes a parent node argument and returns an enumerator on the children
    # to visit.
    #
    # The options is a _symbol_, _symbol_ => _value_ hash or nil. A _symbol_ argument is the same
    # as +{+_symbol_ +=> true}+. Supported options include the following:
    # * +:depth_first+: +true+, +false+ or a Proc. If the value is a Proc, then
    #   value determines whether a child is visited depth-first. See the {#visit} method for more
    #   information.
    #
    # If the :operator option is set, then the visit operator block is called when a node is visited.
    # The operator block argument is the visited node.
    #
    # @param [Symbol, {Symbol => Object}] opts the visit options. A symbol argument is the same
    #   as symbol => true
    # @option opts [String] :depth_first depth-first traversal
    # @option opts [Proc] :operator the operator applied to each visited node
    # @option opts [String] :prune_cycle flag indicating whether to exclude cycles to the root in a visit
    # @option opts [Boolean] :verbose print navigation log messages
    # @yield [parent] returns an enumerator on the children to visit
    # @yieldparam parent the current node
    def initialize(opts=nil, &navigator)
      raise ArgumentError.new('Visitor cannot be created without a navigator block') unless block_given?
      @navigator = navigator
      @options = Options.to_hash(opts)
      @depth_first_flag = @options[:depth_first]
      @prune_cycle_flag = @options[:prune_cycle]
      @lineage = []
      @cycles = []
      @visited = {}
      @verbose = Options.get(:verbose, opts, false)
      @exclude = Set.new
    end
  
    # Navigates to node and the children returned by this Visitor's navigator block.
    # Applies the optional operator block to each child node if the block is given to this method.
    # Returns the result of the operator block if given, or the node itself otherwise.
    #
    # The nodes to visit from a parent node are determined in the following sequence:
    # * Return if the parent node has already been visited.
    # * If depth_first, then call the navigator block defined in the initializer on
    #   the parent node and visit each child node.
    # * Visit the parent node.
    # * If not depth-first, then call the navigator block defined in the initializer
    #   on the parent node and visit each child node.
    # The :depth option value constrains child traversal to that number of levels.
    #
    # This method first clears the _visited_ hash, unless the :visited option was set in the initializer.
    #
    # @param node the root object to visit
    # @yield [visited] an operator applied to each visited object
    # @yieldparam visited the object currently being visited
    # @return the result of the yield block on node, or node itself if no block is given
    def visit(node, &operator)
      visit_root(node, &operator)
    end
  
    # @param node the node to check
    # @return [Boolean] whether the node was visited
    def visited?(node)
      @visited.has_key?(node)
    end
  
    # @return the top node visited
    def root
      @lineage.first
    end
  
    # @return the current node being visited
    def current
      @lineage.last
    end
  
    # @return the node most recently passed as an argument to this visitor's navigator block,
    #   or nil if visiting the first node
    def from
      @lineage[-2]
    end
    
    alias :parent :from
  
    # @return [Enumerable] iterator over each visited node
    def to_enum(node)
      # JRuby could use Generator instead, but that results in dire behavior on any error
      # by crashing with an elided Java lineage trace.
      VisitorEnumerator.new(self, node)
    end
  
    # Returns a new visitor that traverses a collection of parent nodes in lock-step fashion using
    # this visitor. The synced {#visit} method applies the visit operator block to an array of child
    # nodes taken from each parent node, e.g.:
    #   parent1 = Node.new(1)
    #   child11 = Node.new(2, parent1)
    #   child12 = Node.new(3, parent1)
    #   parent2 = Node.new(1)
    #   child21 = Node.new(3, parent2)
    #   Jinx::Visitor.new { |node| node.children }.sync.to_enum.to_a #=> [
    #    [parent1, parent2],
    #    [child11, child21],
    #    [child12, nil]
    #   ]
    #
    # By default, the children are grouped in enumeration order. If a block is given to this method,
    # then the block is called to match child nodes, e.g. using the above example:
    #   visitor = Jinx::Visitor.new { |node| node.children }
    #   synced = visitor.sync { |nodes, others| nodes.to_compact_hash { others.detect { |other| node.value == other.value } } }
    #   synced.to_enum.to_a #=> [
    #     [parent1, parent2],
    #     [child11, nil],
    #     [child12, child21]
    #   ]
    #
    # @yield [nodes, others] matches node in others (optional)
    # @yieldparam [<Resource>] nodes the visited nodes to match
    # @yieldparam [<Resource>] others the candidates for matching the node
    def sync(&matcher)
      SyncVisitor.new(self, &matcher)
    end
  
    # Returns a new Visitor which determines which nodes to visit by applying the given block
    # to this visitor. The filter block arguments consist of a parent node and an array of
    # children nodes for the parent. The block can return nil, a single node to visit or a 
    # collection of nodes to visit.
    #
    # @example
    #   visitor = Jinx::Visitor.new { |person| person.children }
    #   # Joe has age 55 and children aged 17 and 24, who have children aged [1] and [6, 3], resp.
    #   visitor.to_enum(joe) { |person| person.age } #=> [55, 20, 1, 24, 6, 3]
    #   # The filter navigates to the children sorted by age of parents 21 or older.
    #   filter = visitor.filter { |parent, children| children.sort { |c1, c2| c1.age <=> c2.age } if parent.age >= 21 }
    #   filter.to_enum(joe) { |person| person.age } #=> [55, 24, 3, 6]
    #
    # @return [Visitor] the filter visitor
    # @yield [parent, children] the filter to select which of the children to visit next
    # @yieldparam parent the currently visited node
    # @yieldparam children the nodes slated by this Visitor to visit next
    # @raise [ArgumentError] if a block is not given to this method
    def filter
      Jinx.fail(ArgumentError, "A filter block is not given to the visitor filter method") unless block_given?
      Visitor.new(@options) { |node| yield(node, node_children(node)) }
    end
  
    protected
  
    # Resets this visitor's state in preparation for a new visit.
    def clear
      # clear the lineage
      @lineage.clear
      # if the visited hash is not shared, then clear it
      @visited.clear unless @options.has_key?(:visited)
      # clear the cycles
      @cycles.clear
    end
  
    # Returns the children to visit for the given node.
    def node_children(node)
      children = @navigator.call(node)
      return Array::EMPTY_ARRAY if children.nil?
      Enumerable === children ? children.to_a.compact : [children]
    end
  
    private
    
    # @return [Boolean] whether the depth-first flag is set
    def depth_first?
      !!@depth_first_flag
    end
  
    # Visits the root node and all descendants.
    def visit_root(node, &operator)
      clear
      prune_cycle_nodes(node) if @prune_cycle_flag
      # visit the root node
      visit_recursive(node, &operator)
    end
  
    # Excludes the internal nodes in cycles starting and ending at the given root.
    def prune_cycle_nodes(root)
      @exclude.clear
      # visit the root, which will detect cycles, and remove the visited nodes afterwords
      @prune_cycle_flag = false
      to_enum(root).collect.each { |node| @visited.delete(node) }
      @prune_cycle_flag = true
      # add each cyclic internal node to the exclude list
      @cycles.each { |cycle| cycle[1...-1].each { |node| @exclude << node } if cycle.first == root }
    end
  
    def visit_recursive(node, &operator)
      # bail if no node or the node is specifically excluded
      return if node.nil? or @exclude.include?(node)
      # return the visited value if the node has already been visited
      if @visited.has_key?(node) then
        #capture a cycle
        index = @lineage.index(node)
        if index then
          cycle = @lineage[index..-1] << node
          @cycles << cycle
        end
        return @visited[node]
      end
      # return nil if the node has not been visited but has been navigated in a depth-first visit
      return if @lineage.include?(node)
      # all systems go: visit the node graph
      visit_node_and_children(node, &operator)
    end
  
    # Visits the given node and its children. If this visitor is #{depth_first?}, then the
    # operator is applied to the children before the given node. Otherwise, the operator is
    # applied to the children after the given node. The default operator returns the visited
    # node itself.
    # 
    # @param node the node to visit
    # @yield (see #visit)
    # @yieldparam (see #visit)
    def visit_node_and_children(node, &operator)
      # set the current node
      @lineage.push(node)
      # if depth-first, then visit the children before the current node
      visit_children(node, &operator) if depth_first?
      # apply the operator to the current node, if given
      result = @visited[node] = block_given? ? yield(node) : node
      logger.debug { "#{self} visited #{node.qp} with result #{result.qp}" } if @verbose
      # if not depth-first, then visit the children after the current node
      visit_children(node, &operator) unless depth_first?
      @lineage.pop
      # return the visit result
      result
    end
  
    def visit_children(parent, &operator)
      @navigator.call(parent).enumerate { |child| visit_recursive(child, &operator) }
    end
  
    class VisitorEnumerator
      include Enumerable
  
      def initialize(visitor, node)
        @visitor = visitor
        @root = node
      end
  
      def each
        @visitor.visit(@root) { |node| yield(node) }
      end
    end
  
    class SyncVisitor < Visitor
      # @param [Visitor] visitor the Visitor which will visit synchronized input
      # @yield (see Visitor#sync)
      def initialize(visitor, &matcher)
        # the next node to visit is an array of child node pairs matched by the given matcher block
        super() { |nodes| match_children(visitor, nodes, &matcher) }
      end
  
      # Visits the given pair of nodes.
      #
      # Raises ArgumentError if nodes does not consist of either two node arguments or one two-item Array
      # argument.
      def visit(*nodes)
        if nodes.size == 1 then
          nodes = nodes.first
          Jinx.fail(ArgumentError, "Sync visitor requires a pair of entry nodes") unless nodes.size == 2
        end
        super(nodes)
      end
  
      # Returns an Enumerable which applies the given block to each matched node starting at the given nodes.
      #
      # Raises ArgumentError if nodes does not consist of either two node arguments or one two-item Array
      # argument.
      def to_enum(*nodes)
        if nodes.size == 1 then
          nodes = nodes.first
          Jinx.fail(ArgumentError, "Sync visitor requires a pair of entry nodes") unless nodes.size == 2
        end
        super(nodes)
      end
  
      private
  
      # Returns an array of arrays of matched children from the given parent nodes. The children are matched
      # using the block given to this method, if supplied, or by index otherwise.
      #
      # @see #sync a usage example
      # @yield (see Visitor#sync)
      def match_children(visitor, nodes)
        # the parent nodes
        p1, p2 = nodes
        # this visitor's children
        c1 = visitor.node_children(p1)
        c2 = p2 ? visitor.node_children(p2) : []
  
        # Apply the matcher block on each of this visitor's children and the other children.
        # If no block is given, then group the children by index, which is the transpose of the array of
        # children arrays.
        if block_given? then
          # Match each item in the first children array to an item from the second children array using
          # then given block.
          matches = yield(c1, c2)
          c1.map { |c| [c, matches[c]] }
        else
          # Ensure that both children arrays are the same size.
          others = c2.size <= c1.size ? c2.fill(nil, c2.size...c1.size) : c2[0, c1.size]
          # The children grouped by index is the transpose of the array of children arrays.
          [c1, others].transpose
        end
      end
    end
  end
end
