require 'dynamoid/adapter/local'
require File.expand_path(File.dirname(__FILE__) + '../../../spec_helper')

describe Dynamoid::Adapter::Local do

  unless ENV['ACCESS_KEY'] && ENV['SECRET_KEY']
  
    # BatchGetItem
    it 'performs BatchGetItem with singular keys' do
      Dynamoid::Adapter.create_table('table1', :id)
      Dynamoid::Adapter.put_item('table1', {:id => '1', :name => 'Josh'})
      Dynamoid::Adapter.create_table('table2', :id)
      Dynamoid::Adapter.put_item('table2', {:id => '1', :name => 'Justin'})    
    
      results = Dynamoid::Adapter.batch_get_item('table1' => '1', 'table2' => '1')
      results.size.should == 2
      results['table1'].should include({:name => 'Josh', :id => '1'})
      results['table2'].should include({:name => 'Justin', :id => '1'})
    end
  
    it 'performs BatchGetItem with multiple keys' do
      Dynamoid::Adapter.create_table('table1', :id)
      Dynamoid::Adapter.put_item('table1', {:id => '1', :name => 'Josh'})
      Dynamoid::Adapter.put_item('table1', {:id => '2', :name => 'Justin'})
    
      results = Dynamoid::Adapter.batch_get_item('table1' => ['1', '2'])
      results.size.should == 1
      results['table1'].should include({:name => 'Josh', :id => '1'})
      results['table1'].should include({:name => 'Justin', :id => '2'})
    end
  
    # CreateTable
    it 'performs CreateTable' do
      Dynamoid::Adapter.create_table('Test Table', :id)
    
      Dynamoid::Adapter.list_tables.should include 'Test Table'
    end
  
    # DeleteItem
    it 'performs DeleteItem' do
      Dynamoid::Adapter.create_table('table1', :id)
      Dynamoid::Adapter.put_item('table1', {:id => '1', :name => 'Josh'})
    
      Dynamoid::Adapter.delete_item('table1', '1')
    
      Dynamoid::Adapter.data['table1'][:data].should be_empty
    end
  
    it 'performs DeleteItem for an item that does not exist' do
      Dynamoid::Adapter.create_table('table1', :id)
    
      Dynamoid::Adapter.delete_item('table1', '1')
    
      Dynamoid::Adapter.data['table1'][:data].should be_empty
    end
  
    # DeleteTable
    it 'performs DeleteTable' do
      Dynamoid::Adapter.create_table('table1', :id)
    
      Dynamoid::Adapter.delete_table('table1')
    
      Dynamoid::Adapter.data['table1'].should be_nil
    end
  
    # DescribeTable
  
    # GetItem
    it "performs GetItem for an item that does not exist" do
      Dynamoid::Adapter.create_table('Test Table', :id)
    
      Dynamoid::Adapter.get_item('Test Table', '1').should be_nil
    end
  
    it "performs GetItem for an item that does exist" do
      Dynamoid::Adapter.create_table('Test Table', :id)
      Dynamoid::Adapter.put_item('Test Table', {:id => '1', :name => 'Josh'})
    
      Dynamoid::Adapter.get_item('Test Table', '1').should == {:id => '1', :name => 'Josh'}
    end
  
    # ListTables
    it 'performs ListTables' do
      Dynamoid::Adapter.create_table('Table1', :id)
      Dynamoid::Adapter.create_table('Table2', :id)
    
      Dynamoid::Adapter.list_tables.should include 'Table1'
      Dynamoid::Adapter.list_tables.should include 'Table2'
    end
  
    # PutItem
    it 'performs PutItem for an item that does not exist' do
      Dynamoid::Adapter.create_table('Test Table', :id)
      Dynamoid::Adapter.put_item('Test Table', {:id => '1', :name => 'Josh'})
    
      Dynamoid::Adapter.data['Test Table'].should == { :id => :id, :data => { '1' => { :id=> '1', :name=>"Josh" }}}
    end
  
    # Query
    it 'performs query on a table and returns items' do
      Dynamoid::Adapter.create_table('Test Table', :id)
      Dynamoid::Adapter.put_item('Test Table', {:id => '1', :name => 'Josh'})
    
      Dynamoid::Adapter.query('Test Table', '1').should == { :id=> '1', :name=>"Josh" }
    end
  
    it 'performs query on a table and returns items if there are multiple items' do
      Dynamoid::Adapter.create_table('Test Table', :id)
      Dynamoid::Adapter.put_item('Test Table', {:id => '1', :name => 'Josh'})
      Dynamoid::Adapter.put_item('Test Table', {:id => '2', :name => 'Justin'})
    
      Dynamoid::Adapter.query('Test Table', '1').should == { :id=> '1', :name=>"Josh" }
    end
  
    # Scan
    it 'performs scan on a table and returns items' do
      Dynamoid::Adapter.create_table('Test Table', :id)
      Dynamoid::Adapter.put_item('Test Table', {:id => '1', :name => 'Josh'})
    
      Dynamoid::Adapter.scan('Test Table', :name => 'Josh').should == [{ :id=> '1', :name=>"Josh" }]
    end
  
    it 'performs scan on a table and returns items if there are multiple items but only one match' do
      Dynamoid::Adapter.create_table('Test Table', :id)
      Dynamoid::Adapter.put_item('Test Table', {:id => '1', :name => 'Josh'})
      Dynamoid::Adapter.put_item('Test Table', {:id => '2', :name => 'Justin'})
    
      Dynamoid::Adapter.scan('Test Table', :name => 'Josh').should == [{ :id=> '1', :name=>"Josh" }]
    end
  
    it 'performs scan on a table and returns multiple items if there are multiple matches' do
      Dynamoid::Adapter.create_table('Test Table', :id)
      Dynamoid::Adapter.put_item('Test Table', {:id => '1', :name => 'Josh'})
      Dynamoid::Adapter.put_item('Test Table', {:id => '2', :name => 'Josh'})
    
      Dynamoid::Adapter.scan('Test Table', :name => 'Josh').should == [{ :id=> '1', :name=>"Josh" }, { :id=> '2', :name=>"Josh" }]
    end
    
    it 'performs scan on a table and returns all items if no criteria are specified' do
      Dynamoid::Adapter.create_table('Test Table', :id)
      Dynamoid::Adapter.put_item('Test Table', {:id => '1', :name => 'Josh'})
      Dynamoid::Adapter.put_item('Test Table', {:id => '2', :name => 'Josh'})
    
      Dynamoid::Adapter.scan('Test Table', {}).should == [{ :id=> '1', :name=>"Josh" }, { :id=> '2', :name=>"Josh" }]
    end
  
    # UpdateItem
  
    # UpdateTable
  
    protected
  
    def setup_value(table, key, value)
      Dynamoid::Adapter.data[table][key] = value
    end
    
  end
end
