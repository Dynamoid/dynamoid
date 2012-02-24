require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe "Dynamoid::Adapter" do
  
  it 'extends itself automatically' do
    lambda {Dynamoid::Adapter.list_tables}.should_not raise_error
  end

end
