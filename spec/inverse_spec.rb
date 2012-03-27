require File.expand_path('spec_helper', File.dirname(__FILE__))

module Model
  describe 'Inverse' do
    before(:all) do
      Model.definitions BASE, INVERSE
    end
    
    context '1:1' do
      it "should set the inverse" do
        Parent.property(:spouse).inverse.should == :spouse
      end
    
      it "should set the target inverse type back to self" do
        Parent.property(:spouse).inverse.should == :spouse
      end
    
      it "should enforce inverse integrity" do
        m = Parent.new
        f = Parent.new(:spouse => m)
        m.spouse.should be f
      end
    end
    
    context '1:N' do
      it "should set the inverse" do
        Child.property(:parent).inverse.should == :children
      end

      it "should set the target inverse type back to self" do
        Parent.property(:children).inverse.should == :parent
      end

      it "should enforce inverse integrity" do
        p = Parent.new
        c = Child.new(:parent => p)
        p.children.should include c
      end
    end
    
    context 'M:N' do
      it "should set the inverse" do
        Independent.property(:others).inverse.should == :others
      end
    end
  
    private
  
    # The inverse fixture model definitions.
    # @private
    INVERSE = File.dirname(__FILE__) + '/definitions/model/inverse'
  end
end
