require 'jinx/resource/match_visitor'

module Jinx
  # A MergeVisitor merges a domain object's visitable attributes transitive closure into a target.
  class MergeVisitor < MatchVisitor
    # Creates a new MergeVisitor on domain attributes.
    # The domain attributes to visit are determined by calling the selector block given to
    # this initializer as described in {ReferenceVisitor#initialize}.
    #
    # @param (see MatchVisitor#initialize)
    # @option opts [Proc] :mergeable the block which determines which attributes are merged
    # @option opts [Proc] :matcher the block which matches sources to targets
    # @option opts [Proc] :copier the block which copies an unmatched source
    # @yield (see MatchVisitor#initialize)
    # @yieldparam (see MatchVisitor#initialize)
    def initialize(opts=nil, &selector)
      opts = Options.to_hash(opts)
      # Merge is depth-first, since the source references must be matched, and created if necessary,
      # before they can be merged into the target.
      opts[:depth_first] = true
      @mergeable = opts.delete(:mergeable) || selector
      # each mergeable attribute is matchable
      opts[:matchable] = @mergeable unless @mergeable == selector
      super
    end

    # Visits the source and target reference graphs and recursively merges each matching source
    # reference into its corresponding target reference.
    #
    # If a block is given to this method, then the block is called on each matched (source, target) pair.
    #
    # @alert caCORE caCORE does not enforce reference identity integrity, i.e. a search on object _a_
    # with database record references _a_ => _b_ => _a_, the search result might be _a_ => _b_ => _a'_,
    # where _a.identifier_ == _a'.identifier_. This visit method remedies the caCORE defect by matching
    # source references on a previously matched identifier where possible.
    #
    # @param [Resource] source the domain object to merge from
    # @param [Resource] target the domain object to merge into 
    # @yield [target, source] the optional block to call on the visited source domain object and its
    #   matching target
    # @yieldparam [Resource] target the domain object which matches the visited source
    # @yieldparam [Resource] source the visited source domain object
    def visit(source, target)
      super(source, target) do |src, tgt|
         merge(src, tgt)
         block_given? ? yield(src, tgt) : tgt
      end
    end

    private

    # Merges the given source object into the target object.
    #
    # @param [Resource] source the domain object to merge from
    # @param [Resource] target the domain object to merge into
    # @return [Resource] the merged target
    def merge(source, target)
      # trivial case
      return target if source.equal?(target)
      # the domain attributes to merge
      mas = @mergeable.call(source)
      logger.debug { format_merge_log_message(source, target, mas) }
      # merge the non-domain attributes
      target.merge_attributes(source)
      # merge the source domain attributes into the target
      target.merge(source, mas, @matches)
    end
    
    # @param source (see #merge)
    # @param target (see #merge)
    # @param attributes (see Mergeable#merge)
    # @return [String] the log message
    def format_merge_log_message(source, target, attributes)
      attr_clause = " including domain attributes #{attributes.to_series}" unless attributes.empty?
      "Merging #{source.qp} into #{target.qp}#{attr_clause}..."
    end
  end
end