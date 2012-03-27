module Jinx
  module Resource
    # Matches the given targets to sources using {Resource#match_in}.
    # @private
    class Matcher
      def match(sources, targets)
        unmatched = Set === sources ? sources.dup : sources.to_set
        matches = {}
        targets.each do |tgt|
          src = tgt.match_in(unmatched)
          if src then
            unmatched.delete(src)
            matches[src] = tgt
          end
        end
        matches
      end
    end
  end
end