require File.expand_path('spec_helper', File.dirname(__FILE__))

module Model
  describe 'Metadata' do
    before(:all) do
      Model.definitions BASE, ALIAS
    end

    it "should import a resource class" do
      Parent.should be < Jinx::Resource
    end

    it "should import a resource superclass in the same package" do
      Child.superclass.should be < Jinx::Resource
      Child.superclass.superclass.should_not be < Jinx::Resource
    end
  
    it "should introspect the properties" do
      expect { Child.property(:cardinal) }.to_not raise_error
    end

    it "should alias the reserved id attribute" do
      Child.attributes.should include :identifier
      Child.attributes.should_not include :id
    end

    it "should set the collection property flag" do
      Parent.property(:children).collection?.should be true
    end
    
    it "should set the collection property type" do
      Independent.property(:others).type.should be Independent
    end

    it "should infer the collection property type" do
      Parent.property(:children).type.should be Child
    end
    
    it "should make an empty collection value" do
      Parent.empty_value(:children).class.should < Java::JavaUtil::Collection
    end

    it "should recognize a domain property type" do
      Parent.domain_type(:children).should be Child
      Child.domain_type(:cardinal).should be nil
    end

    it "should recognize a property alias" do
      Child.property(:pals).should be Child.property(:friends)
    end
    
    it "should set the primary key" do
      DomainObject.primary_key_attributes.should == [:identifier]
    end
    
    it "should inherit the primary key" do
      Child.primary_key_attributes.should be DomainObject.primary_key_attributes
    end
    
    it "should set the secondary key" do
      Child.secondary_key_attributes.should == [:name]
    end
  
    private

    ALIAS = File.dirname(__FILE__) + '/definitions/model/alias'
  end
end
