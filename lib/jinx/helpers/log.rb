require 'logger'
require 'singleton'
require 'ftools'
require 'jinx/helpers/collections'
require 'jinx/helpers/options'

# @param [String, IO, nil] dev the optional log file or device
# @return [Jinx::MultilineLogger] the global logger
def logger(dev=nil, opts=nil)
  Jinx::Log.instance.open(dev, opts) if dev or opts
  logger = Jinx.logger
  logger
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
    
    # Opens the log. The default log location is as follows:
    # * +/var/log/caruby.log+ for Linux
    # * +%LOCALAPPDATA%\caRuby\log\caruby.log+ for Windows
    # The default file must be creatable or writable. If the device argument is not
    # provided and there is no suitable default log file, then logging is disabled.
    #
    # @param [String, IO, nil] dev the log file or device
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
      dev ||= default_log_file
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
               
    # The default log file.
    LINUX_LOG_DIR = '/var/log'
    
    # Returns +caruby.log+ in the default log directory, determined as follows:
    # * +/var/log+ for Linux
    # * +%LOCALAPPDATA%//caRuby/log+ for Windows
    # The file must be creatable or writable.
    # 
    # @return [String, nil] the file name if it is is creatable or writable, otherwise nil
    def default_log_file
      # If the standard Linux log location exists, then try that.
      # Otherwise, try the conventional Windows app data location.
      if File.exists?(LINUX_LOG_DIR) then
        file = File.expand_path('caruby.log', LINUX_LOG_DIR)
        file if File.exists?(file) ? File.writable?(file) : File.writable?(LINUX_LOG_DIR)
      else
        # the conventional Windows app data location  
        win_app_dir = ENV['LOCALAPPDATA'] || return
        dir = win_app_dir + '/caRuby/log'
        file = File.expand_path('caruby.log', dir)
        if File.exists?(file) then
          file if File.writable?(file)
        elsif File.directory?(dir) then
          file if File.writable?(dir)
        elsif File.writable?(win_app_dir) then
          file
        end
      end
    end
  end
end