#
# Enables paritioning for these tests, use like so: 
#
# 
#
shared_examples "partitioning" do
  before(:all) do
    @previous_value = Dynamoid::Config.partitioning
    Dynamoid::Config.partitioning = true
  end
  
  after(:all) do
    Dynamoid::Config.partitioning = @previous_value
  end  
end