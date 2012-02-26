require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe "Dynamoid::Config" do
  
  before(:each) do
    Dynamoid::Config.reset_namespace
  end
  
  after(:each) do
    Dynamoid.config {|config| config.namespace = 'dynamoid_tests'}
  end

  it 'returns a namespace for non-Rails apps' do
    Dynamoid::Config.namespace.should == 'dynamoid'
  end
  
  it 'returns a namespace for Rails apps' do
    class Rails; end
    Rails.stubs(:application => stubs(:class => stubs(:parent_name => 'TestApp')))
    Rails.stubs(:env => 'development')
    Dynamoid::Config.send(:option, :namespace, :default => defined?(Rails) ? "dynamoid_#{Rails.application.class.parent_name}_#{Rails.env}" : "dynamoid")
    
    # TODO Make this return what we actually expect
    Dynamoid::Config.namespace.should == "dynamoid_Mocha_development"
  end
  
end
