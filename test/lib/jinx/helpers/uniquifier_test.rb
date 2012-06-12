require File.dirname(__FILE__) + '/../../../helper'
require 'test/unit'
require 'jinx/helpers/uniquifier'

class UniquifierTest < Test::Unit::TestCase
  def test_uniquify
    u1 = Jinx::Uniquifier.instance.uniquify('Groucho')
    u2 = Jinx::Uniquifier.instance.uniquify('Groucho')
    assert_not_equal(u1, u2, "Consequetive uniquifier calls not unique")
  end
end
