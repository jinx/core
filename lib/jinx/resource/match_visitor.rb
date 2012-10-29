require 'jinx/helpers/lazy_hash'
require 'jinx/resource/reference_visitor'

module Jinx
  # A MatchVisitor visits two domain objects' visitable attributes transitive closure in lock-step.
  class MatchVisitor < ReferenceVisitor
    # @return [{Resource => Resource}] the domain object matches
    attr_reader :matches

    # Creates a new visitor which matches source and target domain object references.
    # The domain attributes to visit are determined by calling the selector block given to
    # this initializer. The selector arguments consist of the match source and target.
    #
    # @param (see ReferenceVisitor#initialize)
    # @option opts [Proc] :mergeable the block which determines which attributes are merged
    # @option opts [Proc] :matchable the block which determines which attributes to match
    #   (default is the visit selector)
    # @option opts [:match] :matcher an object which matches sources to targets
    # @option opts [Proc] :copier the block which copies an unmatched source
    # @yield (see ReferenceVisitor#initialize)
    # @yieldparam [Resource] source the matched source object
    def initialize(opts=nil)
      raise ArgumentError.new("Reference visitor missing domain reference selector") unless block_given?
      opts = Options.to_hash(opts)
      @matcher = opts.delete(:matcher) || DEF_MATCHER
      @matchable = opts.delete(:matchable)
      @copier = opts.delete(:copier)
      # the source => target matches
      @matches = {}
      # Apply a filter to the visited reference so that only a matched reference is visited.
      # the reference filter
      flt = opts[:filter]
      opts[:filter] = Proc.new do |src|
        (flt.nil? or flt.call(src)) and !!@matches[src]
      end
      # the class => {id => target} hash
      @id_mtchs = LazyHash.new { Hash.new }
      # Match the source references before navigating from the source to its references, since
      # only a matched reference is visited.
      super do |src|
        tgt = @matches[src]
        # the attributes to match on
        mas = yield(src)
        # match the attribute references
        match_references(src, tgt, mas)
        mas
      end
    end

    # Visits the source and target.
    #
    # If a block is given to this method, then this method returns the evaluation of the block on the visited
    # source reference and its matching copy, if any. The default return value is the target which matches
    # source.
    #
    # @param [Resource] source the match visit source
    # @param [Resource] target the match visit target
    # @yield [target, source] the optional block to call on the matched source and target
    # @yieldparam [Resource] source the visited source domain object
    # @yieldparam [Resource] target the domain object which matches the visited source
    # @yieldparam [Resource] from the visiting domain object
    # @yieldparam [Property] property the visiting property
    def visit(source, target, &block)
      # clear the match hashes
      @matches.clear
      @id_mtchs.clear
      # seed the matches with the top-level source => target
      add_match(source, target)
      # Visit the source reference.
      super(source) { |src| visit_matched(src, &block) }
    end

    private
    
    # Matches sources to targets using {Resource#match_all}
    class DefaultMatcher
      def match(sources, targets, from, attribute)
        Resource.match_all(sources, targets)
      end
    end
    
    DEF_MATCHER = DefaultMatcher.new
    
    # Visits the given source domain object.
    #
    # @param [Resource] source the match visit source
    # @yield [target, source] the optional block to call on the matched source and target
    # @yieldparam [Resource] source the visited source domain object
    # @yieldparam [Resource] target the domain object which matches the visited source
    # @yieldparam [Resource] from the visiting domain object
    # @yieldparam [Property] property the visiting property
    def visit_matched(source)
      tgt = @matches[source] || return
      # Match the unvisited matchable references, if any.
      if @matchable then
        mas = @matchable.call(source) - attributes_to_visit(source)
        mas.each { |ma| match_reference(source, tgt, ma) }
      end
      block_given? ? yield(source, tgt) : tgt
    end
    
    # @param source (see #match_visited)
    # @return [<Resource>] the source match
    # @raise [ValidationError] if there is no match
    def match_for_visited(source)
      target = @matches[source]
      if target.nil? then raise ValidationError.new("Match visitor target not found for #{source}") end
      target
    end

    # @param [Resource] source (see #match_visited)
    # @param [Resource] target the source match
    # @param [<Symbol>] attributes the attributes to match on
    # @return [{Resource => Resource}] the referenced attribute matches
    def match_references(source, target, attributes)
      # collect the references to visit
      matches = {}
      attributes.each do |ma|
        matches.merge!(match_reference(source, target, ma))
      end
      matches
    end
    
    # Matches the given source and target attribute references.
    # The match is performed by this visitor's matcher.
    #
    # @param source (see #visit)
    # @param target (see #visit)
    # @param [Symbol] attribute the parent reference attribute
    # @return [{Resource => Resource}] the referenced source => target matches
    def match_reference(source, target, attribute)
      srcs = source.send(attribute).to_enum
      tgts = target.send(attribute).to_enum
      
      # the match targets
      mtchd_tgts = Set.new
      # capture the matched targets and the the unmatched sources
      unmtchd_srcs = srcs.reject do |src|
        # the prior match, if any
        tgt = match_for(src)
        mtchd_tgts << tgt if tgt
      end
      
      # the unmatched targets
      unmtchd_tgts = tgts.difference(mtchd_tgts)
      logger.debug { "#{qp} matching #{unmtchd_tgts.qp}..." } if @verbose and not unmtchd_tgts.empty?
      # match the residual targets and sources
      rsd_mtchs = @matcher.match(unmtchd_srcs, unmtchd_tgts, source, attribute)
      # add residual matches
      rsd_mtchs.each { |src, tgt| add_match(src, tgt) }
      logger.debug { "#{qp} matched #{rsd_mtchs.qp}..." } if @verbose and not rsd_mtchs.empty?
      # The source => target match hash.
      # If there is a copier, then copy each unmatched source.
      matches = srcs.to_compact_hash { |src| match_for(src) or copy_unmatched(src) }
      
      matches
    end

    # @return the target matching the given source
    def match_for(source)
      @matches[source] or identifier_match(source)
    end
    
    def add_match(source, target)
      @matches[source] = target
      @id_mtchs[source.class][source.identifier] = target if source.identifier
      target
    end

    # @return the target matching the given source on the identifier, if any
    def identifier_match(source)
      tgt = @id_mtchs[source.class][source.identifier] if source.identifier
      @matches[source] = tgt if tgt
    end

    # @return [Resource, nil] a copy of the given source if this ReferenceVisitor has a copier,
    #   nil otherwise
    def copy_unmatched(source)
      return unless @copier
      copy = @copier.call(source)
      logger.debug { "#{qp} copied unmatched #{source} to #{copy}." } if @verbose
      add_match(source, copy)
    end
  end
end