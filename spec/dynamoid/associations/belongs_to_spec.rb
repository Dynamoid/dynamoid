require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

describe "Dynamoid::Associations::BelongsTo" do
  
  context 'has many' do
    before do
      @subscription = Subscription.create
      @camel_case = CamelCase.create
    end
  
    it 'determines nil if it has no associated record' do
      @subscription.magazine.should be_nil
    end

    it 'determines target association correctly' do
      @camel_case.magazine.send(:target_association).should == :camel_cases
    end

  
    it 'delegates equality to its source record' do
      @magazine = @subscription.magazine.create
    
      @subscription.magazine.should == @magazine
    end
  
    it 'associates has_many automatically' do
      @magazine = @subscription.magazine.create
    
      @magazine.subscriptions.size.should == 1
      @magazine.subscriptions.should include @subscription

      @magazine = Magazine.create
      @user = @magazine.owner.create
      @user.books.size.should == 1
      @user.books.should include @magazine
    end
    
    it 'behaves like the object it is trying to be' do
      @magazine = @subscription.magazine.create

      @subscription.magazine.update_attribute(:title, 'Test Title')

      Magazine.first.title.should == 'Test Title'
    end
  end
  
  context 'has one' do
    before do
      @sponsor = Sponsor.create
      @subscription = Subscription.create
    end
    
    it 'determins nil if it has no associated record' do
      @sponsor.magazine.should be_nil
    end
  
    it 'delegates equality to its source record' do
      @magazine = @sponsor.magazine.create
    
      @sponsor.magazine.should == @magazine
    end
  
    it 'associates has_one automatically' do
      @magazine = @sponsor.magazine.create
      
      @magazine.sponsor.size.should == 1
      @magazine.sponsor.should == @sponsor

      @user = @subscription.customer.create
      @user.monthly.should == @subscription
    end
  end
end
