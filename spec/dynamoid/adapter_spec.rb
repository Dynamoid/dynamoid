require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe "Dynamoid::Adapter" do
  
  before(:all) do
    Dynamoid::Adapter.create_table('dynamoid_tests_TestTable', :id) unless Dynamoid::Adapter.list_tables.include?('dynamoid_tests_TestTable')
  end
  
  it 'extends itself automatically' do
    lambda {Dynamoid::Adapter.list_tables}.should_not raise_error
  end
  
  it 'raises nomethod if we try a method that is not on the child' do
    lambda {Dynamoid::Adapter.foobar}.should raise_error
  end
  
  context 'without partioning' do
    before(:all) do
      @previous_value = Dynamoid::Config.partitioning
      Dynamoid::Config.partitioning = false
    end
    
    after(:all) do
      Dynamoid::Config.partitioning = @previous_value
    end
    
    it 'writes through the adapter' do
      Dynamoid::Adapter.expects(:put_item).with('dynamoid_tests_TestTable', {:id => '123'}, nil).returns(true)

      Dynamoid::Adapter.write('dynamoid_tests_TestTable', {:id => '123'})
    end

    it 'reads through the adapter for one ID' do
      Dynamoid::Adapter.expects(:get_item).with('dynamoid_tests_TestTable', '123', {}).returns(true)

      Dynamoid::Adapter.read('dynamoid_tests_TestTable', '123')
    end

    it 'reads through the adapter for many IDs' do
      Dynamoid::Adapter.expects(:batch_get_item).with({'dynamoid_tests_TestTable' => ['1', '2']}).returns(true)

      Dynamoid::Adapter.read('dynamoid_tests_TestTable', ['1', '2'])
    end
    
    it 'delete through the adapter for one ID' do
      Dynamoid::Adapter.expects(:delete_item).with('dynamoid_tests_TestTable', '123', {}).returns(nil)

      Dynamoid::Adapter.delete('dynamoid_tests_TestTable', '123')
    end
    
    it 'deletes through the adapter for many IDs' do
      Dynamoid::Adapter.expects(:batch_delete_item).with({'dynamoid_tests_TestTable' => ['1', '2']}).returns(nil)

      Dynamoid::Adapter.delete('dynamoid_tests_TestTable', ['1', '2'])
    end
    
    it 'reads through the adapter for one ID and a range key' do
      Dynamoid::Adapter.expects(:get_item).with('dynamoid_tests_TestTable', '123', :range_key => 2.0).returns(true)

      Dynamoid::Adapter.read('dynamoid_tests_TestTable', '123', :range_key => 2.0)      
    end
    
    it 'reads through the adapter for many IDs and a range key' do
      Dynamoid::Adapter.expects(:batch_get_item).with({'dynamoid_tests_TestTable' => [['1', 2.0], ['2', 2.0]]}).returns(true)

      Dynamoid::Adapter.read('dynamoid_tests_TestTable', ['1', '2'], :range_key => 2.0)
    end
    
    it 'deletes through the adapter for one ID and a range key' do
      Dynamoid::Adapter.expects(:delete_item).with('dynamoid_tests_TestTable', '123', :range_key => 2.0).returns(nil)

      Dynamoid::Adapter.delete('dynamoid_tests_TestTable', '123', :range_key => 2.0)      
    end
    
    it 'deletes through the adapter for many IDs and a range key' do
      Dynamoid::Adapter.expects(:batch_delete_item).with({'dynamoid_tests_TestTable' => [['1', 2.0], ['2', 2.0]]}).returns(nil)

      Dynamoid::Adapter.delete('dynamoid_tests_TestTable', ['1', '2'], :range_key => [2.0,2.0])
    end
  end
  
  context 'with partitioning' do
    before(:all) do
      @previous_value = Dynamoid::Config.partitioning
      Dynamoid::Config.partitioning = true
    end
    
    after(:all) do
      Dynamoid::Config.partitioning = @previous_value
    end
    
    it 'writes through the adapter' do
      Random.expects(:rand).with(Dynamoid::Config.partition_size).once.returns(0)
      Dynamoid::Adapter.write('dynamoid_tests_TestTable', {:id => 'testid'})
    
      Dynamoid::Adapter.get_item('dynamoid_tests_TestTable', 'testid.0')[:id].should == 'testid.0'
      Dynamoid::Adapter.get_item('dynamoid_tests_TestTable', 'testid.0')[:updated_at].should_not be_nil
    end
  
    it 'reads through the adapter for one ID' do
      Dynamoid::Adapter.expects(:batch_get_item).with('dynamoid_tests_TestTable' => (0...Dynamoid::Config.partition_size).collect{|n| "123.#{n}"}).returns({})
    
      Dynamoid::Adapter.read('dynamoid_tests_TestTable', '123')
    end
  
    it 'reads through the adapter for many IDs' do
      Dynamoid::Adapter.expects(:batch_get_item).with('dynamoid_tests_TestTable' => (0...Dynamoid::Config.partition_size).collect{|n| "1.#{n}"} + (0...Dynamoid::Config.partition_size).collect{|n| "2.#{n}"}).returns({})
    
      Dynamoid::Adapter.read('dynamoid_tests_TestTable', ['1', '2'])
    end
    
    it 'reads through the adapter for one ID and a range key' do
      Dynamoid::Adapter.expects(:batch_get_item).with('dynamoid_tests_TestTable' => (0...Dynamoid::Config.partition_size).collect{|n| ["123.#{n}", 2.0]}).returns({})
    
      Dynamoid::Adapter.read('dynamoid_tests_TestTable', '123', :range_key => 2.0)
    end
  
    it 'reads through the adapter for many IDs and a range key' do
      Dynamoid::Adapter.expects(:batch_get_item).with('dynamoid_tests_TestTable' => (0...Dynamoid::Config.partition_size).collect{|n| ["1.#{n}", 2.0]} + (0...Dynamoid::Config.partition_size).collect{|n| ["2.#{n}", 2.0]}).returns({})
    
      Dynamoid::Adapter.read('dynamoid_tests_TestTable', ['1', '2'], :range_key => 2.0)
    end
  
    it 'returns an ID with all partitions' do
      Dynamoid::Adapter.id_with_partitions('1').should =~ (0...Dynamoid::Config.partition_size).collect{|n| "1.#{n}"}
    end
    
    it 'returns an ID and range key with all partitions' do
      Dynamoid::Adapter.id_with_partitions([['1', 1.0]]).should =~ (0...Dynamoid::Config.partition_size).collect{|n| ["1.#{n}", 1.0]}
    end
  
    it 'returns a result for one partitioned element' do
      @time = DateTime.now
      @array =[{:id => '1.0', :updated_at => @time - 6.hours}, {:id => '1.1', :updated_at => @time - 3.hours}, {:id => '1.2', :updated_at => @time - 1.hour}, {:id => '1.3', :updated_at => @time - 6.hours}, {:id => '2.0', :updated_at => @time}]
    
      Dynamoid::Adapter.result_for_partition(@array,"dynamoid_tests_TestTable").should =~ [{:id => '1', :updated_at => @time - 1.hour}, {:id => '2', :updated_at => @time}]
    end
    
    it 'returns a valid original id and partition number' do
      @id = "12345.387327.-sdf3"
      @partition_number = "4"
      Dynamoid::Adapter.get_original_id_and_partition("#{@id}.#{@partition_number}").should == [@id, @partition_number]
    end
    
    it 'delete through the adapter for one ID' do
      Dynamoid::Adapter.expects(:batch_delete_item).with('dynamoid_tests_TestTable' => (0...Dynamoid::Config.partition_size).collect{|n| "123.#{n}"}).returns(nil)

      Dynamoid::Adapter.delete('dynamoid_tests_TestTable', '123')
    end
    
    it 'deletes through the adapter for many IDs' do
      Dynamoid::Adapter.expects(:batch_delete_item).with('dynamoid_tests_TestTable' => (0...Dynamoid::Config.partition_size).collect{|n| "1.#{n}"} + (0...Dynamoid::Config.partition_size).collect{|n| "2.#{n}"}).returns(nil)

      Dynamoid::Adapter.delete('dynamoid_tests_TestTable', ['1', '2'])
    end
    
    it 'deletes through the adapter for one ID and a range key' do
      Dynamoid::Adapter.expects(:batch_delete_item).with('dynamoid_tests_TestTable' => (0...Dynamoid::Config.partition_size).collect{|n| ["123.#{n}", 2.0]}).returns(nil)

      Dynamoid::Adapter.delete('dynamoid_tests_TestTable', '123', :range_key => 2.0)      
    end
    
    it 'deletes through the adapter for many IDs and a range key' do
      Dynamoid::Adapter.expects(:batch_delete_item).with('dynamoid_tests_TestTable' => (0...Dynamoid::Config.partition_size).collect{|n| ["1.#{n}", 2.0]} + (0...Dynamoid::Config.partition_size).collect{|n| ["2.#{n}", 2.0]}).returns(nil)

      Dynamoid::Adapter.delete('dynamoid_tests_TestTable', ['1', '2'], :range_key => [2.0,2.0])
    end
  end

end
