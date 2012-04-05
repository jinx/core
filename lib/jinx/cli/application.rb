require 'logger'

module Jinx
  module CLI
    # Extends the standard Logger::Application to use the {Log} and add start
    # functionality.
    class Application < Logger::Application
      # @param [String] appname the application name
      def initialize(appname=nil)
        super(appname)
        # set the application logger
        @log = logger
        @log.progname = @appname
        @level = @log.level
      end
      
      # Overrides Logger::Application start with the following enhancements:
      # * pass arguments and a block to the application run method
      # * improve the output messages
      # * print an exception to stderr as well as the log
      def start(*args, &block)
        status = 1
        begin
          status = run(*args, &block)
        rescue
          log(FATAL, "#{@appname} detected an exception: #{$!}\n#{$@.qp}")
          msg = "#{@appname} was unsuccessful: #{$!}."
          msg += "\nSee the log #{Log.instance.file} for more information." if Log.instance.file
          $stderr.puts msg
        ensure
          log(INFO, "#{@appname} completed with status #{status}.")
        end
      end
    end
  end
end
