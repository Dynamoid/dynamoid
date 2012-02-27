require 'dynamoid/adapter/aws_sdk'
require File.expand_path(File.dirname(__FILE__) + '../../../spec_helper')

describe Dynamoid::Adapter::AwsSdk do
  
  if ENV['ACCESS_KEY'] && ENV['SECRET_KEY']
    
    context 'without a preexisting table' do
      # CreateTable and DeleteTable
      it 'performs CreateTable and DeleteTable' do
        table = Dynamoid::Adapter.create_table('CreateTable', :id)

        Dynamoid::Adapter.connection.tables.collect{|t| t.name}.should include 'CreateTable'

        Dynamoid::Adapter.delete_table('CreateTable')
      end
    end
    
    context 'with a preexisting table' do
      before(:all) do
        Dynamoid::Adapter.create_table('dynamoid_tests_TestTable1', :id) unless Dynamoid::Adapter.list_tables.include?('dynamoid_tests_TestTable1')
        Dynamoid::Adapter.create_table('dynamoid_tests_TestTable2', :id) unless Dynamoid::Adapter.list_tables.include?('dynamoid_tests_TestTable2')
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
      
      # ListTables
      it 'performs ListTables' do
        Dynamoid::Adapter.list_tables.should include 'dynamoid_tests_TestTable1'
        Dynamoid::Adapter.list_tables.should include 'dynamoid_tests_TestTable2'
      end
      
      # Query
      it 'performs query on a table and returns items' do
        Dynamoid::Adapter.put_item('dynamoid_tests_TestTable1', {:id => '1', :name => 'Josh'})

        Dynamoid::Adapter.query('dynamoid_tests_TestTable1', '1').should == { :id=> '1', :name=>"Josh" }
      end

      it 'performs query on a table and returns items if there are multiple items' do
        Dynamoid::Adapter.put_item('dynamoid_tests_TestTable1', {:id => '1', :name => 'Josh'})
        Dynamoid::Adapter.put_item('dynamoid_tests_TestTable1', {:id => '2', :name => 'Justin'})

        Dynamoid::Adapter.query('dynamoid_tests_TestTable1', '1').should == { :id=> '1', :name=>"Josh" }
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

        Dynamoid::Adapter.scan('dynamoid_tests_TestTable1', :name => 'Josh').should == [{:name=>"Josh", :id=>"2"}, {:name=>"Josh", :id=>"1"}] 
      end
      
      it 'performs scan on a table and returns all items if no criteria are specified' do
        Dynamoid::Adapter.put_item('dynamoid_tests_TestTable1', {:id => '1', :name => 'Josh'})
        Dynamoid::Adapter.put_item('dynamoid_tests_TestTable1', {:id => '2', :name => 'Josh'})

        Dynamoid::Adapter.scan('dynamoid_tests_TestTable1', {}).should == [{:name=>"Josh", :id=>"2"}, {:name=>"Josh", :id=>"1"}] 
      end
      
      
    end
    
    # DescribeTable
    
    # UpdateItem
    
    # UpdateTable
  
  end
end
