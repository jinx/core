# Add the Java jar file to the Java path.
require File.dirname(__FILE__) + '/../../examples/model/ext/bin/model.jar'

# The Jinx Model example application domain module.
module Model
  include Jinx::Resource
  
  # The Java package name.
  packages 'domain'
  
  # expose the definitions for testing
  public_class_method :definitions

  # The base fixture model definitions.
  BASE = File.dirname(__FILE__) + '/../definitions/model/base'
end

