require File.dirname(__FILE__) + '/../../../helper'
require 'test/unit'
require 'jinx/helpers/string_uniquifier'

class StringUniquifierTest < Test::Unit::TestCase
  def test_uniquify
    u1 = Jinx::StringUniquifier.uniquify('Groucho')
    u2 = Jinx::StringUniquifier.uniquify('Groucho')
    assert_not_equal(u1, u2, "Consecutive uniquifier calls not unique")
  end
end
