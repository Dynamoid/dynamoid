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
        Dynamoid::Adapter.create_table('TestTable1', :id)
        Dynamoid::Adapter.create_table('TestTable2', :id)
      end
      
      after(:all) do
        Dynamoid::Adapter.delete_table('TestTable1')
        Dynamoid::Adapter.delete_table('TestTable2')
      end

      # GetItem, PutItem and DeleteItem
      it "performs GetItem for an item that does not exist" do
        Dynamoid::Adapter.get_item('TestTable1', '1').should be_nil
      end

      it "performs GetItem for an item that does exist" do
        Dynamoid::Adapter.put_item('TestTable1', {:id => '1', :name => 'Josh'})

        Dynamoid::Adapter.get_item('TestTable1', '1').should == {:name => 'Josh', :id => '1'}

        Dynamoid::Adapter.delete_item('TestTable1', '1')
        
        Dynamoid::Adapter.get_item('TestTable1', '1').should be_nil
      end
      
      it 'performs DeleteItem for an item that does not exist' do
        Dynamoid::Adapter.delete_item('TestTable1', '1')

        Dynamoid::Adapter.get_item('TestTable1', '1').should be_nil
      end

      it 'performs PutItem for an item that does not exist' do
        Dynamoid::Adapter.put_item('TestTable1', {:id => '1', :name => 'Josh'})

        Dynamoid::Adapter.get_item('TestTable1', '1').should == {:id => '1', :name => 'Josh'}
      end

      # ListTables
      it 'performs ListTables' do
        Dynamoid::Adapter.list_tables.should include 'TestTable1'
        Dynamoid::Adapter.list_tables.should include 'TestTable2'
      end
      
      # Query
      it 'performs query on a table and returns items' do
        Dynamoid::Adapter.put_item('TestTable1', {:id => '1', :name => 'Josh'})

        Dynamoid::Adapter.query('TestTable1', '1').should == { :id=> '1', :name=>"Josh" }
      end

      it 'performs query on a table and returns items if there are multiple items' do
        Dynamoid::Adapter.put_item('TestTable1', {:id => '1', :name => 'Josh'})
        Dynamoid::Adapter.put_item('TestTable1', {:id => '2', :name => 'Justin'})

        Dynamoid::Adapter.query('TestTable1', '1').should == { :id=> '1', :name=>"Josh" }
      end

      # Scan
      it 'performs scan on a table and returns items' do
        Dynamoid::Adapter.put_item('TestTable1', {:id => '1', :name => 'Josh'})

        Dynamoid::Adapter.scan('TestTable1', :name => 'Josh').should == [{ :id=> '1', :name=>"Josh" }]
      end

      it 'performs scan on a table and returns items if there are multiple items but only one match' do
        Dynamoid::Adapter.put_item('TestTable1', {:id => '1', :name => 'Josh'})
        Dynamoid::Adapter.put_item('TestTable1', {:id => '2', :name => 'Justin'})

        Dynamoid::Adapter.scan('TestTable1', :name => 'Josh').should == [{ :id=> '1', :name=>"Josh" }]
      end

      it 'performs scan on a table and returns multiple items if there are multiple matches' do
        Dynamoid::Adapter.put_item('TestTable1', {:id => '1', :name => 'Josh'})
        Dynamoid::Adapter.put_item('TestTable1', {:id => '2', :name => 'Josh'})

        Dynamoid::Adapter.scan('TestTable1', :name => 'Josh').should == [{:name=>"Josh", :id=>"2"}, {:name=>"Josh", :id=>"1"}] 
      end
      
    end
    
    # DescribeTable
  
    # BatchGetItem
    
    # UpdateItem
    
    # UpdateTable
  
  end
end
