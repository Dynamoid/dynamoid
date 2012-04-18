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

    it 'performs BatchGetItem with range keys' do
      Dynamoid::Adapter.create_table('table1', :id, :range_key => { :range => :string })
      Dynamoid::Adapter.put_item('table1', {:id => '1', :range => 1.0})
      Dynamoid::Adapter.put_item('table1', {:id => '2', :range => 2.0})

      results = Dynamoid::Adapter.batch_get_item('table1' => [['1', 1.0], ['2', 2.0]])
      results.size.should == 1
      results['table1'].should include({:id => '1', :range => 1.0})
      results['table1'].should include({:id => '2', :range => 2.0})
    end

    it 'performs BatchGetItem with range keys on one primary key' do
      Dynamoid::Adapter.create_table('table1', :id, :range_key => { :range => :string })
      Dynamoid::Adapter.put_item('table1', {:id => '1', :range => 1.0})
      Dynamoid::Adapter.put_item('table1', {:id => '1', :range => 2.0})

      results = Dynamoid::Adapter.batch_get_item('table1' => [['1', 1.0], ['1', 2.0]])
      results.size.should == 1
      results['table1'].should include({:id => '1', :range => 1.0})
      results['table1'].should include({:id => '1', :range => 2.0})
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

    it "performs GetItem for an item with a range key" do
      Dynamoid::Adapter.create_table('Test Table', :id, :range_key =>  { :range => :number })
      Dynamoid::Adapter.put_item('Test Table', {:id => '1', :range => 1.0})

      Dynamoid::Adapter.get_item('Test Table', '1').should be_nil
      Dynamoid::Adapter.get_item('Test Table', '1', :range_key => 1.0).should == {:id => '1', :range => 1.0}
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

      Dynamoid::Adapter.data['Test Table'].should == {:hash_key=>:id, :range_key=>nil, :data=>{"1."=>{:id=>"1", :name=>"Josh"}}}
    end

    it 'puts an item twice and overwrites an existing item' do
      Dynamoid::Adapter.create_table('Test Table', :id)
      Dynamoid::Adapter.put_item('Test Table', {:id => '1', :name => 'Josh'})
      Dynamoid::Adapter.put_item('Test Table', {:id => '1', :name => 'Justin'})

      Dynamoid::Adapter.data['Test Table'].should == {:hash_key=>:id, :range_key=>nil, :data=>{"1."=>{:id=>"1", :name=>"Justin"}}}
    end

    it 'puts an item twice and does not overwrite an existing item if the range key is not the same' do
      Dynamoid::Adapter.create_table('Test Table', :id, :range_key =>  { :range => :number })
      Dynamoid::Adapter.put_item('Test Table', {:id => '1', :name => 'Justin', :range => 1.0})
      Dynamoid::Adapter.put_item('Test Table', {:id => '1', :name => 'Justin', :range => 2.0})

      Dynamoid::Adapter.data['Test Table'].should == {:hash_key=>:id, :range_key=>:range, :data=>{"1.1.0"=>{:id=>"1", :name=>"Justin", :range => 1.0}, "1.2.0" => {:id=>"1", :name=>"Justin", :range => 2.0}}}
    end

    it 'puts an item twice and does overwrite an existing item if the range key is the same' do
      Dynamoid::Adapter.create_table('Test Table', :id, :range_key => { :range => :number })
      Dynamoid::Adapter.put_item('Test Table', {:id => '1', :name => 'Josh', :range => 1.0})
      Dynamoid::Adapter.put_item('Test Table', {:id => '1', :name => 'Justin', :range => 1.0})

      Dynamoid::Adapter.data['Test Table'].should == {:hash_key=>:id, :range_key=>:range, :data=>{"1.1.0"=>{:id=>"1", :name=>"Justin", :range => 1.0}}}
    end


    # Query
    it 'performs query on a table and returns items' do
      Dynamoid::Adapter.create_table('Test Table', :id)
      Dynamoid::Adapter.put_item('Test Table', {:id => '1', :name => 'Josh'})

      Dynamoid::Adapter.query('Test Table', :hash_value => '1').should == [{ :id=> '1', :name=>"Josh" }]
    end

    it 'performs query on a table and returns items if there are multiple items' do
      Dynamoid::Adapter.create_table('Test Table', :id)
      Dynamoid::Adapter.put_item('Test Table', {:id => '1', :name => 'Josh'})
      Dynamoid::Adapter.put_item('Test Table', {:id => '2', :name => 'Justin'})

      Dynamoid::Adapter.query('Test Table', :hash_value => '1').should == [{ :id=> '1', :name=>"Josh" }]
    end

    context 'range queries' do
      before do
        Dynamoid::Adapter.create_table('Test Table', :id, :range_key => { :range => :number })
        Dynamoid::Adapter.put_item('Test Table', {:id => '1', :range => 1.0})
        Dynamoid::Adapter.put_item('Test Table', {:id => '1', :range => 2.0})
      end

      it 'performs query on a table with a range and selects items in a range' do
        Dynamoid::Adapter.query('Test Table', :hash_value => '1', :range_value => 0.0..3.0).should =~ [{:id => '1', :range => 1.0}, {:id => '1', :range => 2.0}]
      end

      it 'performs query on a table with a range and selects items greater than' do
        Dynamoid::Adapter.query('Test Table', :hash_value => '1', :range_greater_than => 1.0).should =~ [{:id => '1', :range => 2.0}]
      end

      it 'performs query on a table with a range and selects items less than' do
        Dynamoid::Adapter.query('Test Table', :hash_value => '1', :range_less_than => 2.0).should =~ [{:id => '1', :range => 1.0}]
      end

      it 'performs query on a table with a range and selects items gte' do
        Dynamoid::Adapter.query('Test Table', :hash_value => '1', :range_gte => 1.0).should =~ [{:id => '1', :range => 1.0}, {:id => '1', :range => 2.0}]
      end

      it 'performs query on a table with a range and selects items lte' do
        Dynamoid::Adapter.query('Test Table', :hash_value => '1', :range_lte => 2.0).should =~ [{:id => '1', :range => 1.0}, {:id => '1', :range => 2.0}]
      end

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
