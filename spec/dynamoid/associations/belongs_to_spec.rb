require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

describe "Dynamoid::Associations::BelongsTo" do
  
  context 'has many' do
    before do
      @subscription = Subscription.create
      @camel_case = CamelCase.create
    end
  
    it 'determines nil if it has no associated record' do
      expect(@subscription.magazine).to be_nil
    end

    it 'determines target association correctly' do
      expect(@camel_case.magazine.send(:target_association)).to eq :camel_cases
    end

  
    it 'delegates equality to its source record' do
      @magazine = @subscription.magazine.create

      expect(@subscription.magazine).to eq @magazine
    end
  
    it 'associates has_many automatically' do
      @magazine = @subscription.magazine.create
    
      expect(@magazine.subscriptions).to include @subscription

      @magazine = Magazine.create
      @user = @magazine.owner.create
      expect(@user.books.size).to eq 1
      expect(@user.books).to include @magazine
    end
    
    it 'behaves like the object it is trying to be' do
      @magazine = @subscription.magazine.create

      @subscription.magazine.update_attribute(:title, 'Test Title')

      expect(Magazine.first.title).to eq 'Test Title'
    end
  end
  
  context 'has one' do
    before do
      @sponsor = Sponsor.create
      @subscription = Subscription.create
    end
    
    it 'determins nil if it has no associated record' do
      expect(@sponsor.magazine).to be_nil
    end
  
    it 'delegates equality to its source record' do
      @magazine = @sponsor.magazine.create
    
      expect(@sponsor.magazine).to eq @magazine
    end
  
    it 'associates has_one automatically' do
      @magazine = @sponsor.magazine.create
      
      expect(@magazine.sponsor).to eq @sponsor

      @user = @subscription.customer.create
      expect(@user.monthly).to eq @subscription
    end
  end
end
