require File.expand_path('spec_helper', File.dirname(__FILE__))

module Model
  describe 'Dependency' do
    before(:all) do
      Model.definitions BASE, DEPENDENCY
    end
    
    context '1:1' do
      it "should capture the dependents" do
        d = Dependent.new
        c = Child.new(:dependent => d)
        c.dependents.should include d
      end
    end
    
    context '1:N' do
      it "should set the logical flag" do
        Parent.property(:children).logical?.should be true
      end

      it "should set the inverses" do
        Child.property(:parent).inverse.should be :children
        Parent.property(:children).inverse.should be :parent
      end

      it "should capture the dependents" do
        p = Parent.new
        c = Child.new(:parent => p)
        p.dependents.should include c
      end

      it "should fail to validate a missing owner" do
        c = Child.new
        expect { c.validate }.to raise_error(Jinx::ValidationError)
      end

      it "should validate an existing owner" do
        p = Parent.new
        c = Child.new(:parent => p, :name => 'Sam')
        expect { c.validate }.to_not raise_error
      end
    end
  
    private
  
    # The dependency fixture model definitions.
    # @private
    DEPENDENCY = File.dirname(__FILE__) + '/definitions/model/dependency'
  end
end
