require 'jinx/helpers/hashable'

class Hash
  include Jinx::Hashable

  # The EMPTY_HASH constant is an immutable empty hash, used primarily as a default argument.
  class << EMPTY_HASH ||= Hash.new
    def []=(key, value)
      Jinx.fail(NotImplementedError, "Modification of the constant empty hash is not supported")
    end
  end
end
