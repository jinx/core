require File.expand_path('spec_helper', File.dirname(__FILE__))
require File.dirname(__FILE__) + '/../examples/family/lib/family'

module Family
  describe DomainObject do
    it "should set the primary key attribute" do
      DomainObject.primary_key_attributes.should == [:identifier]
    end
  end
  
  describe Address do
    it "should have an attribute => value constructor" do
      Address.new(:state => 'OR').state.should == 'OR'
    end
    
    it "should recognize an alias" do
      a = Address.new(:postal_code => '95111')
      a.zip.should == a.postal_code
    end
  end
  
  describe Parent do
    it "should inherit the primary key" do
      Parent.primary_key_attributes.should be DomainObject.primary_key_attributes
    end
    
    it "should have a secondary key" do
      Parent.secondary_key_attributes.should == [:ssn]
    end
    
    it "should have a name property" do
      Parent.property_defined?(:name).should be true
    end
    
    it "should have a children dependent" do
      Parent.property(:children).dependent?.should be true
    end
  end
  
  describe Child do
    it "should have a parents owner" do
      Child.property(:parents).owner?.should be true
    end
    
    it "should add itself to the household inverse" do
      h = Household.new
      c = Child.new(:household => h)
      h.members.should include c
    end
    
    it "should not add itself to the parents inverse" do
      p = Parent.new
      c = Child.new(:parents => [p])
      p.children.should_not include c
    end
  end
  
  describe Household do
    it "should have a dependent address" do
      a = Address.new
      Household.new(:address => a).dependents.should include a
    end
  end
end
