require File.expand_path('spec_helper', File.dirname(__FILE__))

module Model
  describe 'Mandatory' do
    before(:all) do
      Model.definitions BASE, MANDATORY
    end

    it "should recognize the mandatory property" do
      Child.property(:flag).mandatory?.should be true
    end

    it "should fail to validate a missing mandatory property value" do
      c = Child.new
      expect { c.validate }.to raise_error(Jinx::ValidationError)
    end

    it "should validate an existing mandatory property value" do
      c = Child.new(:name => 'Sam')
      c.flag = true
      expect { c.validate }.to_not raise_error
    end

    it "should validate a mandatory property set to false" do
      c = Child.new(:name => 'Sam')
      c.flag = false
      expect { c.validate }.to_not raise_error
    end

    it "should not revalidate a property" do
      c = Child.new(:name => 'Sam')
      c.flag = true
      expect { c.validate }.to_not raise_error
      c.flag = nil
      expect { c.validate }.to_not raise_error
    end
  
    private

    # The defaults fixture model definitions.
    MANDATORY = File.dirname(__FILE__) + '/definitions/model/mandatory'
  end
end