# Add the Java jar file to the Java path.
require File.dirname(__FILE__) + '/../ext/bin/family.jar'

# The Jinx Model example application domain module.
module Family
  include Jinx::Resource
  
  # The Java package name.
  packages 'family'
  
  # The JRuby mix-ins are in the model subdirectory.
  definitions File.dirname(__FILE__) + '/family'
end
