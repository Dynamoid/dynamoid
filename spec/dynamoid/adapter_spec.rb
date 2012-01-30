require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe "Dynamoid::Adapter" do
  
  it 'extends itself automatically' do
    Dynamoid::Adapter.data.should be_empty
  end

end
