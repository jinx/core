require 'jinx/resource/merge_visitor'

module Jinx
  # A CopyVisitor copies a domain object's visitable attributes transitive closure.
  class CopyVisitor < MergeVisitor
    # Creates a new CopyVisitor with the options described in {MergeVisitor#initialize}.
    # The default :copier option is {Resource#copy}.
    #
    # @param (see MergeVisitor#initialize)
    # @option opts [Proc] :mergeable the mergeable domain attribute selector
    # @option opts [Proc] :matcher the match block
    # @option opts [Proc] :copier the unmatched source copy block
    # @yield (see MergeVisitor#initialize)
    # @yieldparam (see MergeVisitor#initialize)
    def initialize(opts=nil)
      opts = Options.to_hash(opts)
      opts[:copier] ||= Proc.new { |src| src.copy }
      # no match forces a copy
      opts[:matcher] = self
      super
    end

    # Copies the given source domain object's reference graph.
    #
    # @param (see MergeVisitor#visit)
    # @return [Resource] the source copy
    def visit(source)
      target = @copier.call(source)
      super(source, target)
    end
    
    def match(sources, targets, from=nil, property=nil)
      Hash::EMPTY_HASH
    end
  end
end