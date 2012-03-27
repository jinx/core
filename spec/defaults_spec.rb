require File.expand_path('spec_helper', File.dirname(__FILE__))

module Model
  describe 'Defaults' do
    before(:all) do
      Model.definitions BASE, DEFAULTS
    end

    it "should recognize the property default" do
      Child.defaults[:cardinal].should be 1
    end

    it "should set the default property value" do
      c = Child.new
      c.add_defaults
      c.cardinal.should be 1
    end

    it "should not reset a property value to the default" do
      c = Child.new(:cardinal => 2)
      c.add_defaults
      c.cardinal.should be 2
    end
  
    private

    # The defaults fixture model definitions.
    DEFAULTS = File.dirname(__FILE__) + '/definitions/model/defaults'
  end
end
