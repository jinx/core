module Jinx
  # A unique identifier generator.
  module UID
    # Returns a relatively unique integer. Successive calls to this method
    # within the same time zone spaced more than a millisecond apart return different
    # integers. Each generated qualifier is greater than the previous by an unspecified
    # amount.
    def self.generate
      # the first date that this method could be called
      @first ||= Date.new(2011, 12, 01)
      # days as integer + milliseconds as fraction since the first date
      diff = DateTime.now - @first
      # shift a tenth of a milli up into the integer portion
      decimillis = diff * 24 * 60 * 60 * 10000
      # truncate the fraction
      decimillis.truncate
    end
  end
end
