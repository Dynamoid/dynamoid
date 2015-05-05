require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe "Dynamoid::Config" do

  before(:each) do
    Dynamoid::Config.reset_namespace
  end
  
  after(:each) do
    Dynamoid.config {|config| config.namespace = 'dynamoid_tests'}
  end

  it 'returns a namespace for non-Rails apps' do
    expect(Dynamoid::Config.namespace).to eq 'dynamoid'
  end

  it 'returns a namespace for Rails apps' do
    class Rails; end
    test_app = double('test_app', class: double('test_app_class', parent_name: 'Parent'))

    allow(Rails).to receive(:application).and_return(test_app)
    allow(Rails).to receive(:env).and_return('development')
    Dynamoid::Config.send(:option, :namespace, :default => defined?(Rails) ? "dynamoid_#{Rails.application.class.parent_name}_#{Rails.env}" : "dynamoid")
    
    # TODO Make this return what we actually expect
    expect(Dynamoid::Config.namespace).to eq "dynamoid_Parent_development"
  end
  
end
