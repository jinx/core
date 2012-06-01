require File.dirname(__FILE__) + '/../../../helper'
require 'test/unit'
require 'jinx/helpers/associative'

class AssociativeTest < Test::Unit::TestCase
  def test_get
    hash = {'a' => 1}
    assoc = Jinx::Associative.new { |k| hash[k.to_s] }
    assert_equal(1, assoc[:a], "Associative access incorrect.")
    assert_nil(assoc[:b], "Associative access incorrectly returns a value.")
  end
  
  def test_set
    hash = {'a' => 1}
    assoc = Jinx::Associative.new { |k| hash[k.to_s] }.writer { |k, v| hash[k.to_s] = v }
    assert_equal(1, assoc[:a], "Associative access incorrect.")
    assert_nil(assoc[:b], "Associative access incorrectly returns a value.")
    assoc[:b] = 2
    assert_equal(2, assoc[:b], "Associative writer incorrect.")
    # reset the value
    assoc[:a] = 3
    assert_equal(3, assoc[:a], "Associative writer incorrect.")
    # test the ||= idiom
    assert_equal(4, assoc[:c] ||= 4, "Associative writer incorrect.") 
  end
end
