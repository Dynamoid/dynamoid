require 'dynamoid/adapter/aws_sdk'
require File.expand_path(File.dirname(__FILE__) + '../../../spec_helper')

describe Dynamoid::Adapter::AwsSdk do
  before(:each) do
    pending "You must have an active DynamoDB connection" unless ENV['ACCESS_KEY'] && ENV['SECRET_KEY']
  end

  #
  # These let() definitions create tables "dynamoid_tests_TestTable<N>" and return the
  # name of the table. An after(:each) handler drops any tables created this way after each test
  #
  # Name => Constructor args
  {
    1 => [:id],
    2 => [:id],
    3 => [:id, {:range_key => {:range => :number}}],
    4 => [:id, {:range_key => {:range => :number}}]
  }.each do |n, args|
    name = "dynamoid_tests_TestTable#{n}"
    let(:"test_table#{n}") do
      Dynamoid::Adapter.create_table(name, *args)
      @created_tables << name
      name
    end
  end
  
  before(:each) { @created_tables = [] }
  after(:each) do
    @created_tables.each do |t|
      Dynamoid::Adapter.delete_table(t)
    end
  end
  
  #
  # Returns a random key parition if partitioning is on, or an empty string if
  # it is off, useful for shared examples where partitioning may or may not be on
  #
  def key_partition
    Dynamoid::Config.partitioning? ? ".#{Random.rand(Dynamoid::Config.partition_size)}" : ''
  end
    
  #
  # Tests adapter against ranged tables
  #
  shared_examples 'range queries' do
    before do
      Dynamoid::Adapter.put_item(test_table3, {:id => "1#{key_partition}", :range => 1.0})
      Dynamoid::Adapter.put_item(test_table3, {:id => "1#{key_partition}", :range => 3.0})
    end

    it 'performs query on a table with a range and selects items in a range' do
      Dynamoid::Adapter.query(test_table3, :hash_value => '1', :range_value => 0.0..3.0).should =~ [{:id => '1', :range => BigDecimal.new(1)}, {:id => '1', :range => BigDecimal.new(3)}]
    end

    it 'performs query on a table with a range and selects items greater than' do
      Dynamoid::Adapter.query(test_table3, :hash_value => '1', :range_greater_than => 1.0).should =~ [{:id => '1', :range => BigDecimal.new(3)}]
    end

    it 'performs query on a table with a range and selects items less than' do
      Dynamoid::Adapter.query(test_table3, :hash_value => '1', :range_less_than => 2.0).should =~ [{:id => '1', :range => BigDecimal.new(1)}]
    end

    it 'performs query on a table with a range and selects items gte' do
      Dynamoid::Adapter.query(test_table3, :hash_value => '1', :range_gte => 1.0).should =~ [{:id => '1', :range => BigDecimal.new(1)}, {:id => '1', :range => BigDecimal.new(3)}]
    end

    it 'performs query on a table with a range and selects items lte' do
      Dynamoid::Adapter.query(test_table3, :hash_value => '1', :range_lte => 3.0).should =~ [{:id => '1', :range => BigDecimal.new(1)}, {:id => '1', :range => BigDecimal.new(3)}]
    end
  end
  
  #
  # Tests scan_index_forwards flag behavior on range queries
  #
  shared_examples 'correct ordering' do
    before(:each) do
      pending "Order is not preserved on paritioned tables" if(Dynamoid::Config.partitioning?)
      Dynamoid::Adapter.put_item(test_table4, {:id => "1#{key_partition}", :order => 1, :range => 1.0})
      Dynamoid::Adapter.put_item(test_table4, {:id => "1#{key_partition}", :order => 2, :range => 2.0})
      Dynamoid::Adapter.put_item(test_table4, {:id => "1#{key_partition}", :order => 3, :range => 3.0})
      Dynamoid::Adapter.put_item(test_table4, {:id => "1#{key_partition}", :order => 4, :range => 4.0})
      Dynamoid::Adapter.put_item(test_table4, {:id => "1#{key_partition}", :order => 5, :range => 5.0})
      Dynamoid::Adapter.put_item(test_table4, {:id => "1#{key_partition}", :order => 6, :range => 6.0})
    end

    it 'performs query on a table with a range and selects items less than that is in the correct order, scan_index_forward true' do
      query = Dynamoid::Adapter.query(test_table4, :hash_value => '1', :range_greater_than => 0, :scan_index_forward => true)
      query[0].should == {:id => '1', :order => 1, :range => BigDecimal.new(1)}
      query[1].should == {:id => '1', :order => 2, :range => BigDecimal.new(2)}
      query[2].should == {:id => '1', :order => 3, :range => BigDecimal.new(3)}
      query[3].should == {:id => '1', :order => 4, :range => BigDecimal.new(4)}
      query[4].should == {:id => '1', :order => 5, :range => BigDecimal.new(5)}
      query[5].should == {:id => '1', :order => 6, :range => BigDecimal.new(6)}
    end
    
    it 'performs query on a table with a range and selects items less than that is in the correct order, scan_index_forward false' do
      query = Dynamoid::Adapter.query(test_table4, :hash_value => '1', :range_greater_than => 0, :scan_index_forward => false)
      query[5].should == {:id => '1', :order => 1, :range => BigDecimal.new(1)}
      query[4].should == {:id => '1', :order => 2, :range => BigDecimal.new(2)}
      query[3].should == {:id => '1', :order => 3, :range => BigDecimal.new(3)}
      query[2].should == {:id => '1', :order => 4, :range => BigDecimal.new(4)}
      query[1].should == {:id => '1', :order => 5, :range => BigDecimal.new(5)}
      query[0].should == {:id => '1', :order => 6, :range => BigDecimal.new(6)}
    end
  end
  
  
  context 'without a preexisting table' do
    # CreateTable and DeleteTable
    it 'performs CreateTable and DeleteTable' do
      table = Dynamoid::Adapter.create_table('CreateTable', :id, :range_key =>  { :created_at => :number })

      Dynamoid::Adapter.connection.tables.collect{|t| t.name}.should include 'CreateTable'

      Dynamoid::Adapter.delete_table('CreateTable')
    end
  end


  context 'with a preexisting table without paritioning' do
    # GetItem, PutItem and DeleteItem
    it "performs GetItem for an item that does not exist" do
      Dynamoid::Adapter.get_item(test_table1, '1').should be_nil
    end

    it "performs GetItem for an item that does exist" do
      Dynamoid::Adapter.put_item(test_table1, {:id => '1', :name => 'Josh'})

      Dynamoid::Adapter.get_item(test_table1, '1').should == {:name => 'Josh', :id => '1'}

      Dynamoid::Adapter.delete_item(test_table1, '1')

      Dynamoid::Adapter.get_item(test_table1, '1').should be_nil
    end

    it 'performs GetItem for an item that does exist with a range key' do
      Dynamoid::Adapter.put_item(test_table3, {:id => '1', :name => 'Josh', :range => 2.0})

      Dynamoid::Adapter.get_item(test_table3, '1', :range_key => 2.0).should == {:name => 'Josh', :id => '1', :range => 2.0}

      Dynamoid::Adapter.delete_item(test_table3, '1', :range_key => 2.0)

      Dynamoid::Adapter.get_item(test_table3, '1', :range_key => 2.0).should be_nil
    end

    it 'performs DeleteItem for an item that does not exist' do
      Dynamoid::Adapter.delete_item(test_table1, '1')

      Dynamoid::Adapter.get_item(test_table1, '1').should be_nil
    end

    it 'performs PutItem for an item that does not exist' do
      Dynamoid::Adapter.put_item(test_table1, {:id => '1', :name => 'Josh'})

      Dynamoid::Adapter.get_item(test_table1, '1').should == {:id => '1', :name => 'Josh'}
    end

    # BatchGetItem
    it "performs BatchGetItem with singular keys" do
      Dynamoid::Adapter.put_item(test_table1, {:id => '1', :name => 'Josh'})
      Dynamoid::Adapter.put_item(test_table2, {:id => '1', :name => 'Justin'})

      results = Dynamoid::Adapter.batch_get_item(test_table1 => '1', test_table2 => '1')
      results.size.should == 2
      results[test_table1].should include({:name => 'Josh', :id => '1'})
      results[test_table2].should include({:name => 'Justin', :id => '1'})
    end

    it "performs BatchGetItem with multiple keys" do
      Dynamoid::Adapter.put_item(test_table1, {:id => '1', :name => 'Josh'})
      Dynamoid::Adapter.put_item(test_table1, {:id => '2', :name => 'Justin'})

      results = Dynamoid::Adapter.batch_get_item(test_table1 => ['1', '2'])
      results.size.should == 1
      results[test_table1].should include({:name => 'Josh', :id => '1'})
      results[test_table1].should include({:name => 'Justin', :id => '2'})
    end

    it 'performs BatchGetItem with one ranged key' do
      Dynamoid::Adapter.put_item(test_table3, {:id => '1', :name => 'Josh', :range => 1.0})
      Dynamoid::Adapter.put_item(test_table3, {:id => '2', :name => 'Justin', :range => 2.0})

      results = Dynamoid::Adapter.batch_get_item(test_table3 => [['1', 1.0]])
      results.size.should == 1
      results[test_table3].should include({:name => 'Josh', :id => '1', :range => 1.0})
    end

    it 'performs BatchGetItem with multiple ranged keys' do
      Dynamoid::Adapter.put_item(test_table3, {:id => '1', :name => 'Josh', :range => 1.0})
      Dynamoid::Adapter.put_item(test_table3, {:id => '2', :name => 'Justin', :range => 2.0})

      results = Dynamoid::Adapter.batch_get_item(test_table3 => [['1', 1.0],['2', 2.0]])
      results.size.should == 1
      results[test_table3].should include({:name => 'Josh', :id => '1', :range => 1.0})
      results[test_table3].should include({:name => 'Justin', :id => '2', :range => 2.0})
    end
    
    # BatchDeleteItem
    it "performs BatchDeleteItem with singular keys" do
      Dynamoid::Adapter.put_item(test_table1, {:id => '1', :name => 'Josh'})
      Dynamoid::Adapter.put_item(test_table2, {:id => '1', :name => 'Justin'})

      Dynamoid::Adapter.batch_delete_item(test_table1 => ['1'], test_table2 => ['1'])
      
      results = Dynamoid::Adapter.batch_get_item(test_table1 => '1', test_table2 => '1')
      results.size.should == 0
      
      results[test_table1].should_not include({:name => 'Josh', :id => '1'})
      results[test_table2].should_not include({:name => 'Justin', :id => '1'})
    end

    it "performs BatchDeleteItem with multiple keys" do
      Dynamoid::Adapter.put_item(test_table1, {:id => '1', :name => 'Josh'})
      Dynamoid::Adapter.put_item(test_table1, {:id => '2', :name => 'Justin'})

      Dynamoid::Adapter.batch_delete_item(test_table1 => ['1', '2'])
      
      results = Dynamoid::Adapter.batch_get_item(test_table1 => ['1', '2'])
      results.size.should == 0
      
      results[test_table1].should_not include({:name => 'Josh', :id => '1'})
      results[test_table1].should_not include({:name => 'Justin', :id => '2'})
    end

    it 'performs BatchDeleteItem with one ranged key' do
      Dynamoid::Adapter.put_item(test_table3, {:id => '1', :name => 'Josh', :range => 1.0})
      Dynamoid::Adapter.put_item(test_table3, {:id => '2', :name => 'Justin', :range => 2.0})

      Dynamoid::Adapter.batch_delete_item(test_table3 => [['1', 1.0]])
      results = Dynamoid::Adapter.batch_get_item(test_table3 => [['1', 1.0]])
      results.size.should == 0

      results[test_table3].should_not include({:name => 'Josh', :id => '1', :range => 1.0})
    end

    it 'performs BatchDeleteItem with multiple ranged keys' do
      Dynamoid::Adapter.put_item(test_table3, {:id => '1', :name => 'Josh', :range => 1.0})
      Dynamoid::Adapter.put_item(test_table3, {:id => '2', :name => 'Justin', :range => 2.0})

      Dynamoid::Adapter.batch_delete_item(test_table3 => [['1', 1.0],['2', 2.0]])
      results = Dynamoid::Adapter.batch_get_item(test_table3 => [['1', 1.0],['2', 2.0]])
      results.size.should == 0
       
      results[test_table3].should_not include({:name => 'Josh', :id => '1', :range => 1.0})
      results[test_table3].should_not include({:name => 'Justin', :id => '2', :range => 2.0})
    end

    # ListTables
    it 'performs ListTables' do
      #Force creation of the tables
      test_table1; test_table2; test_table3; test_table4

      Dynamoid::Adapter.list_tables.should include test_table1
      Dynamoid::Adapter.list_tables.should include test_table2
    end

    # Query
    it 'performs query on a table and returns items' do
      Dynamoid::Adapter.put_item(test_table1, {:id => '1', :name => 'Josh'})

      Dynamoid::Adapter.query(test_table1, :hash_value => '1').should == { :id=> '1', :name=>"Josh" }
    end

    it 'performs query on a table and returns items if there are multiple items' do
      Dynamoid::Adapter.put_item(test_table1, {:id => '1', :name => 'Josh'})
      Dynamoid::Adapter.put_item(test_table1, {:id => '2', :name => 'Justin'})

      Dynamoid::Adapter.query(test_table1, :hash_value => '1').should == { :id=> '1', :name=>"Josh" }
    end
    
    it_behaves_like 'range queries'

    # Scan
    it 'performs scan on a table and returns items' do
      Dynamoid::Adapter.put_item(test_table1, {:id => '1', :name => 'Josh'})

      Dynamoid::Adapter.scan(test_table1, :name => 'Josh').should == [{ :id=> '1', :name=>"Josh" }]
    end

    it 'performs scan on a table and returns items if there are multiple items but only one match' do
      Dynamoid::Adapter.put_item(test_table1, {:id => '1', :name => 'Josh'})
      Dynamoid::Adapter.put_item(test_table1, {:id => '2', :name => 'Justin'})

      Dynamoid::Adapter.scan(test_table1, :name => 'Josh').should == [{ :id=> '1', :name=>"Josh" }]
    end

    it 'performs scan on a table and returns multiple items if there are multiple matches' do
      Dynamoid::Adapter.put_item(test_table1, {:id => '1', :name => 'Josh'})
      Dynamoid::Adapter.put_item(test_table1, {:id => '2', :name => 'Josh'})

      Dynamoid::Adapter.scan(test_table1, :name => 'Josh').should include({:name=>"Josh", :id=>"2"}, {:name=>"Josh", :id=>"1"})
    end

    it 'performs scan on a table and returns all items if no criteria are specified' do
      Dynamoid::Adapter.put_item(test_table1, {:id => '1', :name => 'Josh'})
      Dynamoid::Adapter.put_item(test_table1, {:id => '2', :name => 'Josh'})

      Dynamoid::Adapter.scan(test_table1, {}).should include({:name=>"Josh", :id=>"2"}, {:name=>"Josh", :id=>"1"})
    end
    
    it_behaves_like 'correct ordering'
  end
  
  context 'with a preexisting table with paritioning' do
    before(:all) do
      @previous_value = Dynamoid::Config.partitioning
      Dynamoid::Config.partitioning = true
    end

    after(:all) do
      Dynamoid::Config.partitioning = @previous_value
    end

    # Query
    it 'performs query on a table and returns items' do
      Dynamoid::Adapter.put_item(test_table1, {:id => '1.1', :name => 'Josh'})

      Dynamoid::Adapter.query(test_table1, :hash_value => '1').first.should == { :id=> '1', :name=>"Josh" }
    end

    it 'performs query on a table and returns items if there are multiple items' do
      Dynamoid::Adapter.put_item(test_table1, {:id => '1.1', :name => 'Josh'})
      Dynamoid::Adapter.put_item(test_table1, {:id => '2.1', :name => 'Justin'})

      Dynamoid::Adapter.query(test_table1, :hash_value => '1').first.should == { :id=> '1', :name=>"Josh" }
    end

    it_behaves_like 'range queries'

    # Scan
    it 'performs scan on a table and returns items' do
      Dynamoid::Adapter.put_item(test_table1, {:id => '1.1', :name => 'Josh'})

      Dynamoid::Adapter.scan(test_table1, :name => 'Josh').should == [{ :id=> '1', :name=>"Josh" }]
    end

    it 'performs scan on a table and returns items if there are multiple items but only one match' do
      Dynamoid::Adapter.put_item(test_table1, {:id => '1.1', :name => 'Josh'})
      Dynamoid::Adapter.put_item(test_table1, {:id => '2.1', :name => 'Justin'})

      Dynamoid::Adapter.scan(test_table1, :name => 'Josh').should == [{ :id=> '1', :name=>"Josh" }]
    end

    it 'performs scan on a table and returns multiple items if there are multiple matches' do
      Dynamoid::Adapter.put_item(test_table1, {:id => '1.1', :name => 'Josh'})
      Dynamoid::Adapter.put_item(test_table1, {:id => '2.1', :name => 'Josh'})

      Dynamoid::Adapter.scan(test_table1, :name => 'Josh').should include({:name=>"Josh", :id=>"2"}, {:name=>"Josh", :id=>"1"})
    end

    it 'performs scan on a table and returns all items if no criteria are specified' do
      Dynamoid::Adapter.put_item(test_table1, {:id => '1.1', :name => 'Josh'})
      Dynamoid::Adapter.put_item(test_table1, {:id => '2.1', :name => 'Josh'})

      Dynamoid::Adapter.scan(test_table1, {}).should include({:name=>"Josh", :id=>"2"}, {:name=>"Josh", :id=>"1"})
    end

    it_behaves_like 'correct ordering'
  end

  # DescribeTable

  # UpdateItem

  # UpdateTable
end
