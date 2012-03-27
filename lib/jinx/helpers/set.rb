require 'set'

class Set
  # The standard Set {#merge} is an anomaly among Ruby collections, since merge modifies the called Set in-place rather
  # than return a new Set containing the merged contents. Preserve this unfortunate behavior, but partially address
  # the anomaly by adding the merge! alias for in-place merge.
  alias :merge! :merge
end
