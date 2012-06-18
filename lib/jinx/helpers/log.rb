require 'logger'
require 'singleton'
require 'ftools'
require 'jinx/helpers/collections'
require 'jinx/helpers/options'
require 'jinx/helpers/inflector'

# @param [String, IO, nil] dev the optional log file or device
# @return [Jinx::MultilineLogger] the global logger
def logger(dev=nil, opts=nil)
  Jinx.logger(dev, opts)
end

module Jinx
  # @param [String, IO, nil] dev the optional log file or device
  # @return [Jinx::MultilineLogger] the global logger
  def self.logger(dev=nil, opts=nil)
    Log.instance.open(dev, opts) if dev or opts
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
    
    # Opens the log. The default log location is determined from the application name.
    # The application name is the value of the +:app+ option, or +Jinx+ by default.
    # For an application +MyApp+, the log location is determined as follows:
    # * +/var/log/my_app.log+ for Linux
    # * +%LOCALAPPDATA%\MyApp\log\MyApp.log+ for Windows
    # * +./log/MyApp.log+ otherwise
    # The default file must be creatable or writable. If the device argument is not
    # provided and there is no suitable default log file, then logging is disabled.
    #
    # @param [String, IO, nil] dev the log file or device
    # @param [Hash, nil] opts the logger options
    # @option opts [String] :app the application name
    # @option opts [Integer] :shift_age the number of log files retained in the rotation
    # @option opts [Integer] :shift_size the maximum size of each log file
    # @option opts [Boolean] :debug whether to include debug messages in the log file
    # @return [MultilineLogger] the global logger
    def open(dev=nil, opts=nil)
      if open? then
        raise RuntimeError.new("The logger has already opened the log#{' file ' + @dev if String === @dev}")
      end
      dev, opts = nil, dev if Hash === dev
      dev ||= default_log_file(Options.get(:app, opts)) 
      FileUtils.mkdir_p(File.dirname(dev)) if String === dev
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
               
    # The default log file.
    LINUX_LOG_DIR = '/var/log'
    
    # Returns the log file, as described in {#open}.
    #
    # If the standard Linux log location exists, then try that.
    # Otherwise, try the conventional Windows app data location.
    # If all else fails, use the working directory.
    #
    # The file must be creatable or writable.
    #
    # @param [String, nil] app the application name (default +jinx+) 
    # @return [String] the file name
    def default_log_file(app=nil)
      app ||= 'Jinx'
      default_linux_log_file(app) || default_windows_log_file(app) || "log/#{app}.log"
    end
      
    # @param [String] app the application name
    # @return [String, nil] the default file name
    def default_linux_log_file(app)
      return unless File.exists?(LINUX_LOG_DIR)
      base = app.underscore.gsub(' ', '_')
      file = File.expand_path("#{base}.log", LINUX_LOG_DIR)
      log = file if File.exists?(file) ? File.writable?(file) : File.writable?(LINUX_LOG_DIR)
      log || '/dev/null'
    end
    
    # @param [String] app the application name 
    # @return [String, nil] the default file name
    def default_windows_log_file(app)
      # the conventional Windows app data location  
      app_dir = ENV['LOCALAPPDATA'] || return
      dir = app_dir + "/#{app}/log"
      file = File.expand_path("#{app}.log", dir)
      if File.exists?(file) ? File.writable?(file) : (File.directory?(dir) ? File.writable?(dir) : File.writable?(app_dir)) then
        file
      else
        'NUL'
      end
    end
  end
end
