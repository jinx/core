require 'optparse'
require 'jinx/helpers/log'
require 'jinx/cli/application'

module Jinx
  module CLI
    # Open the log file before start-up.
    log_ndx = ARGV.index("--log") || ARGV.index("-l")
    log_file = log_ndx ? ARGV[log_ndx + 1] : ENV['LOG']
    debug = ARGV.include?('--debug') || ENV['DEBUG'] =~ /true/i
    Log.instance.open(log_file, :debug => debug) if log_file or debug

    # Command-line parsing errors.
    class CommandError < StandardError; end
      
    # Command-line parser and executor.
    class Command < Application
      # Command line application wrapper.
      # The specs parameter is an array of command line option and argument
      # specifications as follows:
      #
      # The option specification has format:
      #
      # [_option_, _short_, _long_, _class_, _description_]
      #
      # where:
      # * _option_ is the option symbol, e.g. +:output+
      # * _short_ is the short option form, e.g. "-o"
      # * _long_ is the long option form, e.g. "--output FILE"
      # * _class_ is the option value class, e.g. Integer
      # * _description_ is the option usage, e.g. "Output file"
      # The _option_, _long_ and _description_ items are required; the _short_
      # and _class_ items can be omitted.
      #
      # The argument specification is an array in the form:
      #
      # [_arg_, _text_]
      #
      # where:
      # * _arg_ is the argument symbol, e.g. +:input+
      # * _text_ is the usage message text, e.g. 'input', '[input]' or 'input ...' 
      # Both _arg_ and _text_ are required.
      #
      # Built-in options include the following:
      # * +--help+ : print the help message and exit
      # * +--verbose+ : print additional information to the console
      # * +--log FILE+ : log file
      # * +--debug+ : print debug messages to the log
      # * +--file FILE+: file containing other options
      # * +--quiet+: suppress printing messages to stdout
      #
      # This class processes these built-in options. Subclasses are responsible for
      # processing any remaining options.
      #
      # @param [<(Symbol, String, String, Class, String), (Symbol, String)>, nil] specs
      #   the command line argument specifications
      # @yield (see #run)
      # @yieldparam (see #run)
      def initialize(specs=Array::EMPTY_ARRAY, &executor)
        @executor = executor
        # Validate the specifications.
        unless Array === specs then
          raise ArgumentError.new("Command-line specification is not an array: #{specs.qp}")
        end
        invalid = specs.detect { |spec| spec.size < 2 }
        if invalid then
          raise ArgumentError.new("Command-line argument specification is missing text: #{invalid.qp}")
        end
        # Options start with a dash, arguments are whatever is left.
        @opt_specs, @arg_specs = specs.partition { |spec| spec[1][0, 1] == '-' }
        # Add the default option specifications.
        @opt_specs.concat(DEF_OPTS)
        # The application name is the command.
        super(File.basename($0, ".bat"))
      end
  
      # Runs this command by calling the block given to this method, if provided,
      # otherwise the block given to {#initialize}
      # option or argument symbol => value hash.
      # @yield [hash] the command execution block
      # @yieldparam [{Symbol => Object}] hash the argument and option symbol => value hash
      def run
        # the option => value hash
        opts = get_opts
        # this base class's options
        handle_options(opts)
        # add the argument => value hash
        opts.merge!(get_args)
        # call the block
        log(INFO, "Starting #{@appname}...")
        block_given? ? yield(opts) : call_executor(opts)
      end
  
      private
      
      # The default options that apply to all commands.
      DEF_OPTS = [
        [:help, "-h", "--help", "Display this help message"],
        [:file, "--file FILE", "Configuration file containing other options"],
        [:log, "--log FILE", "Log file"],
        [:debug, "--debug", "Display debug log messages"],
        [:quiet, "-q", "--quiet", "Suppress printing messages to stdout"],
        [:verbose, "-v", "--verbose", "Print additional messages to stdout"]
      ]

      # @param [{Symbol => Object}] opts the option => value hash
      def call_executor(opts)
         if @executor.nil? then Jinx.fail(CommandError, "Command #{self} does not have an execution block") end
         @executor.call(opts)
      end
      
      # Collects the command line options.
      #
      # @return [{Symbol => Object}] the option => value hash 
      def get_opts
        # the options hash
        opts = {}
        # the option parser
        OptionParser.new do |parser|
          # The help argument string is comprised of the argument specification labels.
          arg_s = @arg_specs.map { |spec| spec[1] }.join(' ')
          # Build the usage message.
          parser.banner = "Usage: #{parser.program_name} [options] #{arg_s}"
          parser.separator ""
          parser.separator "Options:"
          # parse the options
          opts = parse(parser)
          # grab the usage message
          @usage = parser.help
        end
        opts
      end
  
      # Collects the non-option command line arguments.
      #
      # @return [{Symbol => Object}] the argument => value hash 
      def get_args
        return Hash::EMPTY_HASH if ARGV.empty?
        if @arg_specs.empty? then too_many_arguments end
        # Collect the arguments from the command line.
        args = {}
        # The number of command line arguments or all but the last argument specifications,
        # whichever is less. The last argument can have more than one value, indicated by
        # the argument specification form '...', so it is processed separately below.
        n = [ARGV.size, @arg_specs.size - 1].min
        # the single-valued arguments
        n.times { |i| args[@arg_specs[i].first] = ARGV[i] }
        # Process the last argument.
        if n < ARGV.size then
          spec = @arg_specs.last
          arg, form = spec[0], spec[1]
          # A multi-valued last argument is the residual command argument array.
          # A single-valued last argument is the last value, if there is exactly one.
          # Otherwise, there are too many arguments.
          if form.index('...') then
            args[arg] = ARGV[n..-1]
          elsif @arg_specs.size == ARGV.size then
            args[arg] = ARGV[n]
          else
            too_many_arguments
          end
        end
        args
      end
      
      def too_many_arguments
        halt("Too many arguments - expected #{@arg_specs.size}, found: #{ARGV.join(' ')}.", 1)
      end
      
      # @param [OptionParser] parser the option parser
      # @return [{Symbol => Object}] the option => value hash
      def parse(parser)
        opts = {}
        @opt_specs.each do |opt, *spec|
          parser.on_tail(*spec) { |v| opts[opt] = v }
        end
        # build the option => value hash 
        parser.parse!
        opts
      end
      
      # Processes the built-in options as follows:
      # * +:help+ - print the usage message and exit
      # * +:file+ FILE - load the options specified in the given file
      #
      # @param [{Symbol => Object}] the option => value hash
      def handle_options(opts)
        # if help, then print usage and exit
        if opts[:help] then halt end
        # If there is a file option, then load additional options from the file.
        file = opts.delete(:file)
        if file then
          fopts = File.open(file).map { |line| line.chomp }.split(' ').flatten
          ARGV.concat(fopts)
          OptionParser.new do |p|
            opts.merge!(parse(p)) { |ov, nv| ov ? ov : nv }
          end
        end
      end
      
      # Prints the given error message and the program usage, then exits with status 1.
      def fail(message=nil)
        halt(message, 1)
      end
  
      # Prints the given message and program usage, then exits with the given status.
      def halt(message=nil, status=0)
        puts(message) if message
        puts(@usage)
        exit(status)
      end
    end
  end
end
