require 'rubygems'
require 'bundler/setup'
Bundler.require(:test, :development)
require 'jinx/helpers/log'

# Open the logger.
Jinx::Log.instance.open(File.dirname(__FILE__) + '/results/log/jinx.log', :debug => true)
