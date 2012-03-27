require File.dirname(__FILE__) + '/../../../helper'
require 'test/unit'
require 'jinx/helpers/boolean'

class BooleanTest < Test::Unit::TestCase
  def test_marker
    assert(Boolean === true, "true is not a Boolean")
    assert(Boolean === false, "false is not a Boolean")
    assert(!nil.is_a?(Boolean), "nil is a Boolean")
  end
  
  def test_string
    ['true', 'True', 't', 'T', 'yes', 'Yes', 'y', 'Y', '1'].each do |s|
      assert_equal(true, s.to_boolean, "#{s} is not converted to true")
    end
    ['false', 'False', 'f', 'F', 'no', 'No', 'n', 'N', '0'].each do |s|
      assert_equal(false, s.to_boolean, "#{s} is not converted to false")
    end
    assert_raises(ArgumentError, "Invalid boolean string was converted") { 'Maybe'.to_boolean }
  end
  
  def test_integer
    assert_equal(true, 1.to_boolean, "#{self} is not converted to true")
    assert_equal(false, 0.to_boolean, "#{self} is not converted to false")
    assert_raises(ArgumentError, "Invalid boolean integer was converted") { 3.to_boolean }
  end
end