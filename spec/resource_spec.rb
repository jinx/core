require File.expand_path('spec_helper', File.dirname(__FILE__))

module Model
  describe 'Resource' do
    before(:all) do
      Model.definitions BASE
    end

    it "should have a resource attribute => value constructor" do
      Child.new(:name => 'Test').name.should == 'Test'
    end

    it "should merge an attribute => value hash" do
      c = Child.new(:name => 'Test')
      p = Parent.new
      c.merge({:name => 'Other', :cardinal => 1, :parent => p})
      c.name.should == 'Test'
      c.cardinal.should be 1
      c.parent.should be p
    end

    it "should merge another resource" do
      c = Child.new(:name => 'Test')
      other = Child.new(:name => 'Other', :cardinal => 1)
      c.merge(other)
      c.name.should == 'Test'
      c.cardinal.should be 1
    end
  end
end
