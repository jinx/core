# Add the Java jar file to the Java path.
require File.dirname(__FILE__) + '/../../../fixtures/mixed/ext/bin/mixed_case.jar'

require File.dirname(__FILE__) + '/../../../helper'
require 'java'
require "test/unit"

class MixedCaseTest < Test::Unit::TestCase
  # Verifies whether JRuby supports a mixed-case package.
  # This test case exercises the following JRuby bug:
  #
  # @ quirk JRuby JRuby cannot resolve a class with a mixed-case package name. Although
  #    discouraged, a Java mixed-case package name is legal. The work-around is to 
  #    import the class name instead.
  #
  # @example
  #   # Assuming mixed.Case.Example is in the Java class path, then:
  #   mixed.Case.Example #=> NameError
  #   java_import 'mixed.Case.Example' #=> Class
  #
  # @param [String] jname the fully-qualified Java class or interface name
  # @return [String] the JRuby class or module name
  # @example
  #   Java.to_ruby_class_name('com.test.Sample') #=> Java::ComTest::Sample
  def test_import
    assert_raises(NameError, "Mixed-case package resolved") { Java::mixed.Case.Example }
    assert_raises(NameError, "Mixed-case JRuby module resolved") { Java::MixedCase::Example }
    assert_nothing_raised("Mixed-case import as a string not resolved") { java_import 'mixed.Case.Example' }
  end
end