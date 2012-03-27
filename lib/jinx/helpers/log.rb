require 'logger'
require 'singleton'
require 'ftools'
require 'jinx/helpers/collections'
require 'jinx/helpers/options'

# @return (see Jinx.logger)
def logger
  Jinx.logger
end

module Jinx
  # @return (see Log#logger)
  def self.logger
    Log.instance.logger
  end
  
  # Extends the standard Logger to format multi-line messages on separate lines.
  class MultilineLogger < ::Logger
    # @see Logger#initialize
    def initialize(*args)
      super
    end
    
    # Rackify the logger with a write method, in conformance with
    # the [Rack spec](http://rack.rubyforge.org/doc/SPEC.html).
    alias :write :<<
  
    private
  
    # Writes msg to the log device. Each line in msg is formatted separately.
    #
    # @param (see Logger#format_message)
    # @return (see Logger#format_message)
    def format_message(severity, datetime, progname, msg)
      if String === msg then
        msg.inject('') { |s, line| s << super(severity, datetime, progname, line.chomp) }
      else
        super
      end
    end
  end
  
  # Wraps a standard global Logger.
  class Log
    include Singleton
    
    # Opens the log.
    #
    # @param [String, IO, nil] dev the log file or device (default STDOUT)
    # @param [Hash, nil] opts the logger options
    # @option opts [Integer] :shift_age the number of log files retained in the rotation
    # @option opts [Integer] :shift_size the maximum size of each log file
    # @option opts [Boolean] :debug whether to include debug messages in the log file
    # @return [MultilineLogger] the global logger
    def open(dev=nil, opts=nil)
      raise RuntimeError.new("Log already open") if open?
      if String === dev then File.makedirs(File.dirname(dev)) end
      # default is 4-file rotation @ 16MB each
      shift_age = Options.get(:shift_age, opts, 4)
      shift_size = Options.get(:shift_size, opts, 16 * 1048576)
      @logger = MultilineLogger.new(dev, shift_age, shift_size)
      @logger.level = Options.get(:debug, opts) ? Logger::DEBUG : Logger::INFO
      @logger.formatter = lambda do |severity, time, progname, msg|
        FORMAT % [
          progname || 'I',
          DateTime.now.strftime("%d/%b/%Y %H:%M:%S"),
          severity,
          msg]
      end
      @dev = dev
      @logger
    end
    
    # @return [Boolean] whether the logger is open 
    def open?
      !!@logger
    end
    
    # Closes and releases the {#logger}.
    def close
      @logger.close
      @logger = nil
    end
  
    # @return (see #open)
    def logger
      @logger ||= open
    end
    
    # @return [String, nil] the log file, or nil if the log was opened on an IO rather
    #   than a String
    def file
      @dev if String === @dev
    end
    
    private
    
    # Stream-lined log format.
    FORMAT = %{%s [%s] %5s %s\n}   
    
    def same_file?(f1, f2)
      f1 == f2 or (String === f2 and String === f1 and File.expand_path(f1) == File.expand_path(f2))
    end
  end
end