# Add the Java jar file to the Java path.
require File.dirname(__FILE__) + '/../ext/bin/model.jar'

# The Jinx Model example application domain module.
module Model
  include Jinx::Resource
  
  # The Java package name.
  packages 'domain'
  
  # The JRuby mix-ins are in the model subdirectory.
  definitions File.dirname(__FILE__) + '/model'
end
