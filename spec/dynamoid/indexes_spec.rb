require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe "Dynamoid::Indexes" do
  
  it 'adds indexes to the index array' do
    User.indexes.keys.should =~ [[:created_at], [:created_at, :name], [:email], [:email, :name], [:last_logged_in_at, :name], [:name]]
  end
  
  it 'saves indexes to their tables' do
    @user = User.new(:name => 'Josh')
    
    User.indexes.each {|k, v| v.expects(:save).with(@user).once.returns(true)}
    
    @user.save
  end
    
  it 'deletes indexes when the object is destroyed' do
    @user = User.create(:name => 'Josh')
    
    User.indexes.each {|k, v| v.expects(:delete).with(@user).once.returns(true)}
    
    @user.destroy
  end

end
