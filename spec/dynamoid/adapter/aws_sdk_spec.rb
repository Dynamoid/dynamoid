require 'dynamoid/adapter/aws_sdk'
require File.expand_path(File.dirname(__FILE__) + '../../../spec_helper')

describe Dynamoid::Adapter::AwsSdk do

  if ENV['ACCESS_KEY'] && ENV['SECRET_KEY']

    context 'without a preexisting table' do
      # CreateTable and DeleteTable
      it 'performs CreateTable and DeleteTable' do
        table = Dynamoid::Adapter.create_table('CreateTable', :id, :range_key =>  { :created_at => :number })

        Dynamoid::Adapter.connection.tables.collect{|t| t.name}.should include 'CreateTable'

        Dynamoid::Adapter.delete_table('CreateTable')
      end
    end

    context 'with a preexisting table without paritioning' do
      before(:all) do
        Dynamoid::Adapter.create_table('dynamoid_tests_TestTable1', :id) unless Dynamoid::Adapter.list_tables.include?('dynamoid_tests_TestTable1')
        Dynamoid::Adapter.create_table('dynamoid_tests_TestTable2', :id) unless Dynamoid::Adapter.list_tables.include?('dynamoid_tests_TestTable2')
        Dynamoid::Adapter.create_table('dynamoid_tests_TestTable3', :id, :range_key => { :range => :number }) unless Dynamoid::Adapter.list_tables.include?('dynamoid_tests_TestTable3')
        Dynamoid::Adapter.create_table('dynamoid_tests_TestTable4', :id, :range_key => { :range => :number }) unless Dynamoid::Adapter.list_tables.include?('dynamoid_tests_TestTable4')
      end

      # GetItem, PutItem and DeleteItem
      it "performs GetItem for an item that does not exist" do
        Dynamoid::Adapter.get_item('dynamoid_tests_TestTable1', '1').should be_nil
      end

      it "performs GetItem for an item that does exist" do
        Dynamoid::Adapter.put_item('dynamoid_tests_TestTable1', {:id => '1', :name => 'Josh'})

        Dynamoid::Adapter.get_item('dynamoid_tests_TestTable1', '1').should == {:name => 'Josh', :id => '1'}

        Dynamoid::Adapter.delete_item('dynamoid_tests_TestTable1', '1')

        Dynamoid::Adapter.get_item('dynamoid_tests_TestTable1', '1').should be_nil
      end

      it 'performs GetItem for an item that does exist with a range key' do
        Dynamoid::Adapter.put_item('dynamoid_tests_TestTable3', {:id => '1', :name => 'Josh', :range => 2.0})

        Dynamoid::Adapter.get_item('dynamoid_tests_TestTable3', '1', :range_key => 2.0).should == {:name => 'Josh', :id => '1', :range => 2.0}

        Dynamoid::Adapter.delete_item('dynamoid_tests_TestTable3', '1', :range_key => 2.0)

        Dynamoid::Adapter.get_item('dynamoid_tests_TestTable3', '1', :range_key => 2.0).should be_nil
      end

      it 'performs DeleteItem for an item that does not exist' do
        Dynamoid::Adapter.delete_item('dynamoid_tests_TestTable1', '1')

        Dynamoid::Adapter.get_item('dynamoid_tests_TestTable1', '1').should be_nil
      end

      it 'performs PutItem for an item that does not exist' do
        Dynamoid::Adapter.put_item('dynamoid_tests_TestTable1', {:id => '1', :name => 'Josh'})

        Dynamoid::Adapter.get_item('dynamoid_tests_TestTable1', '1').should == {:id => '1', :name => 'Josh'}
      end

      # BatchGetItem
      it "performs BatchGetItem with singular keys" do
        Dynamoid::Adapter.put_item('dynamoid_tests_TestTable1', {:id => '1', :name => 'Josh'})
        Dynamoid::Adapter.put_item('dynamoid_tests_TestTable2', {:id => '1', :name => 'Justin'})

        results = Dynamoid::Adapter.batch_get_item('dynamoid_tests_TestTable1' => '1', 'dynamoid_tests_TestTable2' => '1')
        results.size.should == 2
        results['dynamoid_tests_TestTable1'].should include({:name => 'Josh', :id => '1'})
        results['dynamoid_tests_TestTable2'].should include({:name => 'Justin', :id => '1'})
      end

      it "performs BatchGetItem with multiple keys" do
        Dynamoid::Adapter.put_item('dynamoid_tests_TestTable1', {:id => '1', :name => 'Josh'})
        Dynamoid::Adapter.put_item('dynamoid_tests_TestTable1', {:id => '2', :name => 'Justin'})

        results = Dynamoid::Adapter.batch_get_item('dynamoid_tests_TestTable1' => ['1', '2'])
        results.size.should == 1
        results['dynamoid_tests_TestTable1'].should include({:name => 'Josh', :id => '1'})
        results['dynamoid_tests_TestTable1'].should include({:name => 'Justin', :id => '2'})
      end

      it 'performs BatchGetItem with one ranged key' do
        Dynamoid::Adapter.put_item('dynamoid_tests_TestTable3', {:id => '1', :name => 'Josh', :range => 1.0})
        Dynamoid::Adapter.put_item('dynamoid_tests_TestTable3', {:id => '2', :name => 'Justin', :range => 2.0})

        results = Dynamoid::Adapter.batch_get_item('dynamoid_tests_TestTable3' => [['1', 1.0]])
        results.size.should == 1
        results['dynamoid_tests_TestTable3'].should include({:name => 'Josh', :id => '1', :range => 1.0})
      end

      it 'performs BatchGetItem with multiple ranged keys' do
        Dynamoid::Adapter.put_item('dynamoid_tests_TestTable3', {:id => '1', :name => 'Josh', :range => 1.0})
        Dynamoid::Adapter.put_item('dynamoid_tests_TestTable3', {:id => '2', :name => 'Justin', :range => 2.0})

        results = Dynamoid::Adapter.batch_get_item('dynamoid_tests_TestTable3' => [['1', 1.0],['2', 2.0]])
        results.size.should == 1
        results['dynamoid_tests_TestTable3'].should include({:name => 'Josh', :id => '1', :range => 1.0})
        results['dynamoid_tests_TestTable3'].should include({:name => 'Justin', :id => '2', :range => 2.0})
      end
      
      # BatchDeleteItem
      it "performs BatchDeleteItem with singular keys" do
        Dynamoid::Adapter.put_item('dynamoid_tests_TestTable1', {:id => '1', :name => 'Josh'})
        Dynamoid::Adapter.put_item('dynamoid_tests_TestTable2', {:id => '1', :name => 'Justin'})

        Dynamoid::Adapter.batch_delete_item('dynamoid_tests_TestTable1' => ['1'], 'dynamoid_tests_TestTable2' => ['1'])
        
        results = Dynamoid::Adapter.batch_get_item('dynamoid_tests_TestTable1' => '1', 'dynamoid_tests_TestTable2' => '1')
        results.size.should == 0
        
        results['dynamoid_tests_TestTable1'].should_not include({:name => 'Josh', :id => '1'})
        results['dynamoid_tests_TestTable2'].should_not include({:name => 'Justin', :id => '1'})
      end

      it "performs BatchDeleteItem with multiple keys" do
        Dynamoid::Adapter.put_item('dynamoid_tests_TestTable1', {:id => '1', :name => 'Josh'})
        Dynamoid::Adapter.put_item('dynamoid_tests_TestTable1', {:id => '2', :name => 'Justin'})

        Dynamoid::Adapter.batch_delete_item('dynamoid_tests_TestTable1' => ['1', '2'])
        
        results = Dynamoid::Adapter.batch_get_item('dynamoid_tests_TestTable1' => ['1', '2'])
        results.size.should == 0
        
        results['dynamoid_tests_TestTable1'].should_not include({:name => 'Josh', :id => '1'})
        results['dynamoid_tests_TestTable1'].should_not include({:name => 'Justin', :id => '2'})
      end

      it 'performs BatchDeleteItem with one ranged key' do
        Dynamoid::Adapter.put_item('dynamoid_tests_TestTable3', {:id => '1', :name => 'Josh', :range => 1.0})
        Dynamoid::Adapter.put_item('dynamoid_tests_TestTable3', {:id => '2', :name => 'Justin', :range => 2.0})

        Dynamoid::Adapter.batch_delete_item('dynamoid_tests_TestTable3' => [['1', 1.0]])
        results = Dynamoid::Adapter.batch_get_item('dynamoid_tests_TestTable3' => [['1', 1.0]])
        results.size.should == 0

        results['dynamoid_tests_TestTable3'].should_not include({:name => 'Josh', :id => '1', :range => 1.0})
      end

      it 'performs BatchDeleteItem with multiple ranged keys' do
        Dynamoid::Adapter.put_item('dynamoid_tests_TestTable3', {:id => '1', :name => 'Josh', :range => 1.0})
        Dynamoid::Adapter.put_item('dynamoid_tests_TestTable3', {:id => '2', :name => 'Justin', :range => 2.0})

        Dynamoid::Adapter.batch_delete_item('dynamoid_tests_TestTable3' => [['1', 1.0],['2', 2.0]])
        results = Dynamoid::Adapter.batch_get_item('dynamoid_tests_TestTable3' => [['1', 1.0],['2', 2.0]])
        results.size.should == 0
         
        results['dynamoid_tests_TestTable3'].should_not include({:name => 'Josh', :id => '1', :range => 1.0})
        results['dynamoid_tests_TestTable3'].should_not include({:name => 'Justin', :id => '2', :range => 2.0})
      end

      # ListTables
      it 'performs ListTables' do
        Dynamoid::Adapter.list_tables.should include 'dynamoid_tests_TestTable1'
        Dynamoid::Adapter.list_tables.should include 'dynamoid_tests_TestTable2'
      end

      # Query
      it 'performs query on a table and returns items' do
        Dynamoid::Adapter.put_item('dynamoid_tests_TestTable1', {:id => '1', :name => 'Josh'})

        Dynamoid::Adapter.query('dynamoid_tests_TestTable1', :hash_value => '1').should == { :id=> '1', :name=>"Josh" }
      end

      it 'performs query on a table and returns items if there are multiple items' do
        Dynamoid::Adapter.put_item('dynamoid_tests_TestTable1', {:id => '1', :name => 'Josh'})
        Dynamoid::Adapter.put_item('dynamoid_tests_TestTable1', {:id => '2', :name => 'Justin'})

        Dynamoid::Adapter.query('dynamoid_tests_TestTable1', :hash_value => '1').should == { :id=> '1', :name=>"Josh" }
      end

      context 'range queries' do
        before do
          Dynamoid::Adapter.put_item('dynamoid_tests_TestTable3', {:id => '1', :range => 1.0})
          Dynamoid::Adapter.put_item('dynamoid_tests_TestTable3', {:id => '1', :range => 3.0})
        end

        it 'performs query on a table with a range and selects items in a range' do
          Dynamoid::Adapter.query('dynamoid_tests_TestTable3', :hash_value => '1', :range_value => 0.0..3.0).should =~ [{:id => '1', :range => BigDecimal.new(1)}, {:id => '1', :range => BigDecimal.new(3)}]
        end

        it 'performs query on a table with a range and selects items greater than' do
          Dynamoid::Adapter.query('dynamoid_tests_TestTable3', :hash_value => '1', :range_greater_than => 1.0).should =~ [{:id => '1', :range => BigDecimal.new(3)}]
        end

        it 'performs query on a table with a range and selects items less than' do
          Dynamoid::Adapter.query('dynamoid_tests_TestTable3', :hash_value => '1', :range_less_than => 2.0).should =~ [{:id => '1', :range => BigDecimal.new(1)}]
        end

        it 'performs query on a table with a range and selects items gte' do
          Dynamoid::Adapter.query('dynamoid_tests_TestTable3', :hash_value => '1', :range_gte => 1.0).should =~ [{:id => '1', :range => BigDecimal.new(1)}, {:id => '1', :range => BigDecimal.new(3)}]
        end

        it 'performs query on a table with a range and selects items lte' do
          Dynamoid::Adapter.query('dynamoid_tests_TestTable3', :hash_value => '1', :range_lte => 3.0).should =~ [{:id => '1', :range => BigDecimal.new(1)}, {:id => '1', :range => BigDecimal.new(3)}]
        end
      end

      # Scan
      it 'performs scan on a table and returns items' do
        Dynamoid::Adapter.put_item('dynamoid_tests_TestTable1', {:id => '1', :name => 'Josh'})

        Dynamoid::Adapter.scan('dynamoid_tests_TestTable1', :name => 'Josh').should == [{ :id=> '1', :name=>"Josh" }]
      end

      it 'performs scan on a table and returns items if there are multiple items but only one match' do
        Dynamoid::Adapter.put_item('dynamoid_tests_TestTable1', {:id => '1', :name => 'Josh'})
        Dynamoid::Adapter.put_item('dynamoid_tests_TestTable1', {:id => '2', :name => 'Justin'})

        Dynamoid::Adapter.scan('dynamoid_tests_TestTable1', :name => 'Josh').should == [{ :id=> '1', :name=>"Josh" }]
      end

      it 'performs scan on a table and returns multiple items if there are multiple matches' do
        Dynamoid::Adapter.put_item('dynamoid_tests_TestTable1', {:id => '1', :name => 'Josh'})
        Dynamoid::Adapter.put_item('dynamoid_tests_TestTable1', {:id => '2', :name => 'Josh'})

        Dynamoid::Adapter.scan('dynamoid_tests_TestTable1', :name => 'Josh').should include({:name=>"Josh", :id=>"2"}, {:name=>"Josh", :id=>"1"})
      end

      it 'performs scan on a table and returns all items if no criteria are specified' do
        Dynamoid::Adapter.put_item('dynamoid_tests_TestTable1', {:id => '1', :name => 'Josh'})
        Dynamoid::Adapter.put_item('dynamoid_tests_TestTable1', {:id => '2', :name => 'Josh'})

        Dynamoid::Adapter.scan('dynamoid_tests_TestTable1', {}).should include({:name=>"Josh", :id=>"2"}, {:name=>"Josh", :id=>"1"})
      end
      
      context 'correct ordering ' do
        before do
          Dynamoid::Adapter.put_item('dynamoid_tests_TestTable4', {:id => '1', :order => 1, :range => 1.0})
          Dynamoid::Adapter.put_item('dynamoid_tests_TestTable4', {:id => '1', :order => 2, :range => 2.0})
          Dynamoid::Adapter.put_item('dynamoid_tests_TestTable4', {:id => '1', :order => 3, :range => 3.0})
          Dynamoid::Adapter.put_item('dynamoid_tests_TestTable4', {:id => '1', :order => 4, :range => 4.0})
          Dynamoid::Adapter.put_item('dynamoid_tests_TestTable4', {:id => '1', :order => 5, :range => 5.0})
          Dynamoid::Adapter.put_item('dynamoid_tests_TestTable4', {:id => '1', :order => 6, :range => 6.0})
        end

        it 'performs query on a table with a range and selects items less than that is in the correct order, scan_index_forward true' do
          query = Dynamoid::Adapter.query('dynamoid_tests_TestTable4', :hash_value => '1', :range_greater_than => 0, :scan_index_forward => true)
          query[0].should == {:id => '1', :order => 1, :range => BigDecimal.new(1)}
          query[1].should == {:id => '1', :order => 2, :range => BigDecimal.new(2)}
          query[2].should == {:id => '1', :order => 3, :range => BigDecimal.new(3)}
          query[3].should == {:id => '1', :order => 4, :range => BigDecimal.new(4)}
          query[4].should == {:id => '1', :order => 5, :range => BigDecimal.new(5)}
          query[5].should == {:id => '1', :order => 6, :range => BigDecimal.new(6)}
        end
        
        it 'performs query on a table with a range and selects items less than that is in the correct order, scan_index_forward false' do
          query = Dynamoid::Adapter.query('dynamoid_tests_TestTable4', :hash_value => '1', :range_greater_than => 0, :scan_index_forward => false)
          query[5].should == {:id => '1', :order => 1, :range => BigDecimal.new(1)}
          query[4].should == {:id => '1', :order => 2, :range => BigDecimal.new(2)}
          query[3].should == {:id => '1', :order => 3, :range => BigDecimal.new(3)}
          query[2].should == {:id => '1', :order => 4, :range => BigDecimal.new(4)}
          query[1].should == {:id => '1', :order => 5, :range => BigDecimal.new(5)}
          query[0].should == {:id => '1', :order => 6, :range => BigDecimal.new(6)}
        end
      end
    end
    
    context 'with a preexisting table with paritioning' do
      before(:all) do
        @previous_value = Dynamoid::Config.partitioning
        Dynamoid::Config.partitioning = true
        
        Dynamoid::Adapter.create_table('dynamoid_tests_TestTable1', :id) unless Dynamoid::Adapter.list_tables.include?('dynamoid_tests_TestTable1')
        Dynamoid::Adapter.create_table('dynamoid_tests_TestTable2', :id) unless Dynamoid::Adapter.list_tables.include?('dynamoid_tests_TestTable2')
        Dynamoid::Adapter.create_table('dynamoid_tests_TestTable3', :id, :range_key => { :range => :number }) unless Dynamoid::Adapter.list_tables.include?('dynamoid_tests_TestTable3')
      end

      after(:all) do
        Dynamoid::Config.partitioning = @previous_value
      end

      # Query
      it 'performs query on a table and returns items' do
        Dynamoid::Adapter.put_item('dynamoid_tests_TestTable1', {:id => '1.1', :name => 'Josh'})

        Dynamoid::Adapter.query('dynamoid_tests_TestTable1', :hash_value => '1').first.should == { :id=> '1', :name=>"Josh" }
      end

      it 'performs query on a table and returns items if there are multiple items' do
        Dynamoid::Adapter.put_item('dynamoid_tests_TestTable1', {:id => '1.1', :name => 'Josh'})
        Dynamoid::Adapter.put_item('dynamoid_tests_TestTable1', {:id => '2.1', :name => 'Justin'})

        Dynamoid::Adapter.query('dynamoid_tests_TestTable1', :hash_value => '1').first.should == { :id=> '1', :name=>"Josh" }
      end

      context 'range queries' do
        before do
          Dynamoid::Adapter.put_item('dynamoid_tests_TestTable3', {:id => '1.1', :range => 1.0})
          Dynamoid::Adapter.put_item('dynamoid_tests_TestTable3', {:id => '1.1', :range => 3.0})
        end

        it 'performs query on a table with a range and selects items in a range' do
          Dynamoid::Adapter.query('dynamoid_tests_TestTable3', :hash_value => '1', :range_value => 0.0..3.0).should =~ [{:id => '1', :range => BigDecimal.new(1)}, {:id => '1', :range => BigDecimal.new(3)}]
        end

        it 'performs query on a table with a range and selects items greater than' do
          Dynamoid::Adapter.query('dynamoid_tests_TestTable3', :hash_value => '1', :range_greater_than => 1.0).should =~ [{:id => '1', :range => BigDecimal.new(3)}]
        end

        it 'performs query on a table with a range and selects items less than' do
          Dynamoid::Adapter.query('dynamoid_tests_TestTable3', :hash_value => '1', :range_less_than => 2.0).should =~ [{:id => '1', :range => BigDecimal.new(1)}]
        end

        it 'performs query on a table with a range and selects items gte' do
          Dynamoid::Adapter.query('dynamoid_tests_TestTable3', :hash_value => '1', :range_gte => 1.0).should =~ [{:id => '1', :range => BigDecimal.new(1)}, {:id => '1', :range => BigDecimal.new(3)}]
        end

        it 'performs query on a table with a range and selects items lte' do
          Dynamoid::Adapter.query('dynamoid_tests_TestTable3', :hash_value => '1', :range_lte => 3.0).should =~ [{:id => '1', :range => BigDecimal.new(1)}, {:id => '1', :range => BigDecimal.new(3)}]
        end
      end

      # Scan
      it 'performs scan on a table and returns items' do
        Dynamoid::Adapter.put_item('dynamoid_tests_TestTable1', {:id => '1.1', :name => 'Josh'})

        Dynamoid::Adapter.scan('dynamoid_tests_TestTable1', :name => 'Josh').should == [{ :id=> '1', :name=>"Josh" }]
      end

      it 'performs scan on a table and returns items if there are multiple items but only one match' do
        Dynamoid::Adapter.put_item('dynamoid_tests_TestTable1', {:id => '1.1', :name => 'Josh'})
        Dynamoid::Adapter.put_item('dynamoid_tests_TestTable1', {:id => '2.1', :name => 'Justin'})

        Dynamoid::Adapter.scan('dynamoid_tests_TestTable1', :name => 'Josh').should == [{ :id=> '1', :name=>"Josh" }]
      end

      it 'performs scan on a table and returns multiple items if there are multiple matches' do
        Dynamoid::Adapter.put_item('dynamoid_tests_TestTable1', {:id => '1.1', :name => 'Josh'})
        Dynamoid::Adapter.put_item('dynamoid_tests_TestTable1', {:id => '2.1', :name => 'Josh'})

        Dynamoid::Adapter.scan('dynamoid_tests_TestTable1', :name => 'Josh').should include({:name=>"Josh", :id=>"2"}, {:name=>"Josh", :id=>"1"})
      end

      it 'performs scan on a table and returns all items if no criteria are specified' do
        Dynamoid::Adapter.put_item('dynamoid_tests_TestTable1', {:id => '1.1', :name => 'Josh'})
        Dynamoid::Adapter.put_item('dynamoid_tests_TestTable1', {:id => '2.1', :name => 'Josh'})

        Dynamoid::Adapter.scan('dynamoid_tests_TestTable1', {}).should include({:name=>"Josh", :id=>"2"}, {:name=>"Josh", :id=>"1"})
      end
      
      context 'correct ordering ' do
        before do
          Dynamoid::Adapter.put_item('dynamoid_tests_TestTable4', {:id => '1.1', :range => 1.0})
          Dynamoid::Adapter.put_item('dynamoid_tests_TestTable4', {:id => '1.2', :range => 2.0})
          Dynamoid::Adapter.put_item('dynamoid_tests_TestTable4', {:id => '1.3', :range => 3.0})
          Dynamoid::Adapter.put_item('dynamoid_tests_TestTable4', {:id => '1.4', :range => 4.0})
          Dynamoid::Adapter.put_item('dynamoid_tests_TestTable4', {:id => '1.5', :range => 5.0})
          Dynamoid::Adapter.put_item('dynamoid_tests_TestTable4', {:id => '1.6', :range => 6.0})
        end

        it 'performs query on a table with a range and selects items less than that is in the correct order, scan_index_forward true' do
          query = Dynamoid::Adapter.query('dynamoid_tests_TestTable4', :hash_value => '1', :range_greater_than => 0, :scan_index_forward => true)
          query[0].should == {:id => '1', :range => BigDecimal.new(1)}
          query[1].should == {:id => '1', :range => BigDecimal.new(2)}
          query[2].should == {:id => '1', :range => BigDecimal.new(3)}
          query[3].should == {:id => '1', :range => BigDecimal.new(4)}
          query[4].should == {:id => '1', :range => BigDecimal.new(5)}
          query[5].should == {:id => '1', :range => BigDecimal.new(6)}
        end
        
        it 'performs query on a table with a range and selects items less than that is in the correct order, scan_index_forward false' do
          query = Dynamoid::Adapter.query('dynamoid_tests_TestTable4', :hash_value => '1', :range_greater_than => 0, :scan_index_forward => false)
          query[5].should == {:id => '1', :range => BigDecimal.new(1)}
          query[4].should == {:id => '1', :range => BigDecimal.new(2)}
          query[3].should == {:id => '1', :range => BigDecimal.new(3)}
          query[2].should == {:id => '1', :range => BigDecimal.new(4)}
          query[1].should == {:id => '1', :range => BigDecimal.new(5)}
          query[0].should == {:id => '1', :range => BigDecimal.new(6)}
        end
      end
    end

    # DescribeTable

    # UpdateItem

    # UpdateTable

  end
end
