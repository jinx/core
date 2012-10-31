require 'set'
require 'date'
require 'pp'
require 'stringio'
require 'jinx/helpers/options'
require 'jinx/helpers/collections'
require 'jinx/helpers/inflector'

class PrettyPrint
  # The standard +prettyprint+ gem SingleLine is adjusted to add an output accessor and an optional output argument to {#initialize}.
  class SingleLine
    # @return [String] the print target
    attr_reader :output

    alias :base__initialize :initialize
    private :base__initialize

    # Overrides the standard SingleLine initializer to supply an output parameter default.
    def initialize(output='', maxwidth=nil, newline=nil)
      base__initialize(output, maxwidth, newline)
    end
  end
end

# A PrintWrapper prints arguments by calling a printer proc.
class PrintWrapper < Proc
  # Creates a new PrintWrapper on the given arguments.
  def initialize(*args)
    super()
    @args = args
  end

  # @param args this wrapper's print block parameters
  # @return [PrintWrapper] self
  def wrap(*args)
    @args = args
    self
  end

  # Calls this PrintWrapper's print procedure on the arguments set in the initializer.
  def to_s
    @args.empty? ? 'nil' : call(*@args)
  end

  alias :inspect :to_s
end

class Object
  # @return [String] this object's class demodulized name and object id
  def print_class_and_id
    "#{self.class.qp}@#{object_id}"
  end

  # qp, an abbreviation for quick-print, calls {#print_class_and_id} in this base implementation.
  alias :qp :print_class_and_id

  # Formats this object with the standard {PrettyPrint}.
  #
  # @param [Hash, Symbol, nil] opts the print options
  # @option opts [Boolean] :single_line print the output on a single line
  # @return [String] the formatted print result
  def pp_s(opts=nil)
    s = StringIO.new
    if Options.get(:single_line, opts) then
      PP.singleline_pp(self, s)
    else
      PP.pp(self, s)
    end
    s.rewind
    s.read.chomp
  end
end

class Numeric
  # Alias #{Object#qp} to {#to_s} in this primitive class.
  alias :qp :to_s
end

class String
  # Alias #{Object#qp} to {#to_s} in this primitive class.
  alias :qp :to_s
end

class TrueClass
  # Alias #{Object#qp} to {#to_s} in this primitive class.
  alias :qp :to_s
end

class FalseClass
  # Alias #{Object#qp} to {#to_s} in this primitive class.
  alias :qp :to_s
end

class NilClass
  # Alias #{Object#qp} to {#to_s} in this primitive class.
  alias :qp :inspect
end

class Symbol
  # Alias #{Object#qp} to {#to_s} in this primitive class.
  alias :qp :inspect
end

class Module
  # @return [String ] the demodulized name
  def qp
    name[/\w+$/]
  end
end

module Enumerable
  # Prints this Enumerable with a filter that calls qp on each item.
  # Non-collection Enumerable classes override this method to delegate to {Object#qp}.
  #
  # Unlike {Object#qp}, this implementation accepts the {Object#pp_s} options.
  # The options are used to format this Enumerable, but are not propagated to the
  # enumerated items.
  #
  # @param (see Object#pp_s)
  # @return [String] the formatted result
  def qp(opts=nil)
    wrap { |item| item.qp }.pp_s(opts)
  end

  # If a transformer block is given to this method, then the block is applied to each
  # enumerated item before pretty-printing the result.
  #
  # @param (see Object#pp_s)
  # @yield [item] transforms the item to print
  # @yieldparam item the item to print
  # @return (see Oblect#pp_s)
  def pp_s(opts=nil)
    # delegate to Object if no block
    return super unless block_given?
    # make a print wrapper
    wrapper = PrintWrapper.new { |item| yield item }
    # print using the wrapper on each item
    wrap { |item| wrapper.wrap(item) }.pp_s(opts)
  end

  # Pretty-prints the content within brackets, as is done by the Array pretty printer.
  def pretty_print(q)
    q.group(1, '[', ']') {
      q.seplist(self) { |v|
        q.pp v
      }
    }
  end

  # Pretty-prints the cycle within brackets, as is done by the Array pretty printer.
  def pretty_print_cycle(q)
    q.text(empty? ? '[]' : '[...]')
  end
end

module Jinx
  module Hasher
    # qp, short for quick-print, prints this Hasher with a filter that calls qp on each key and value.
    #
    # @return [String] the quick-print result
    def qp
      qph = {}
      each { |k, v| qph[k.qp] = v.qp }
      qph.pp_s
    end

    def pretty_print(q)
      Hash === self ? q.pp_hash(self) : q.pp_hash(to_hash)
    end

    def pretty_print_cycle(q)
      q.text(empty? ? '{}' : '{...}')
    end
  end
end

class String
  # Pretty-prints this String using the Object pretty_print rather than Enumerable pretty_print.
  def pretty_print(q)
    q.text self
  end
end

class DateTime
  # Pretty-prints the DateTime +strftime+ to the given queue in the format
  # _date_+T+_hr_+h+_mm_+m+_ss_+s+, e.g. +2010-10-10T04h10m30+.
  #
  # @quirk JRuby pp standard libary bug - Printing the formatted date:time string sporadically
  #   results in a corrupted line, e.g.:
  #     at top level in 2010-10-10T00:00:00-07:00 at line 1 
  #   The Jinx work-around is to substitute the colons with +h+, +m+ and +s+ and omit the GMT offset.
  #   The bug cause is unknown. Perhaps it is a flaw in the line break logic.
  #
  # @param q the print queue
  # @return [String] the formatted date and time
  def pretty_print(q)
    q.text(strftime.sub(/T(\d{2}):(\d{2}):(\d{2})-\d{2}:\d{2}/, 'T\1h\2m\3s'))
  end
  
  # qp, an abbreviation for quick-print, is an alias for {#to_s} in this primitive class.
  alias :qp :to_s
end

class Set
  # Formats this set using {Enumerable#pretty_print}.
  def pretty_print(q)
    # mark this object as visited; this fragment is inferred from pp.rb and is necessary to detect a cycle
    Thread.current[:__inspect_key__] << __id__
    to_a.pretty_print(q)
  end

  # The pp.rb default pretty printing method for general objects that are detected as part of a cycle.
  def pretty_print_cycle(q)
    to_a.pretty_print_cycle(q)
  end
end
