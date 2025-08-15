# frozen_string_literal: true

require 'spec_helper'
require 'fixtures/persistence'

# TODO: review and sort out these specs.
# All the other specs are located in spec/dynamoid/persistence.
describe Dynamoid::Persistence do
  let(:address) { Address.new }

  context 'without AWS keys' do
    unless ENV['ACCESS_KEY'] && ENV['SECRET_KEY']
      before do
        Dynamoid.adapter.delete_table(Address.table_name) if Dynamoid.adapter.list_tables.include?(Address.table_name)
      end

      it 'creates a table' do
        Address.create_table(table_name: Address.table_name)

        expect(Dynamoid.adapter.list_tables).to include 'dynamoid_tests_addresses'
      end

      it 'checks if a table already exists' do
        Address.create_table(table_name: Address.table_name)

        expect(Address).to be_table_exists(Address.table_name)
        expect(Address).not_to be_table_exists('crazytable')
      end
    end
  end

  describe 'record deletion' do
    let(:klass) do
      new_class do
        field :city

        before_destroy do |_i|
          # Halting the callback chain in active record changed with Rails >= 5.0.0.beta1
          # We now have to throw :abort to halt the callback chain
          # See: https://github.com/rails/rails/commit/bb78af73ab7e86fd9662e8810e346b082a1ae193
          if ActiveModel::VERSION::MAJOR < 5
            false
          else
            throw :abort
          end
        end
      end
    end

    describe 'destroy' do
      it 'deletes an item completely' do
        @user = User.create(name: 'Josh')
        @user.destroy

        expect(Dynamoid.adapter.read('dynamoid_tests_users', @user.id)).to be_nil
      end

      it 'returns false when destroy fails (due to callback)' do
        a = klass.create!
        expect(a.destroy).to eql false
        expect(klass.first.id).to eql a.id
      end
    end

    describe 'destroy!' do
      it 'deletes the item' do
        address.save!
        address.destroy!
        expect(Address.count).to eql 0
      end

      it 'raises exception when destroy fails (due to callback)' do
        a = klass.create!
        expect { a.destroy! }.to raise_error(Dynamoid::Errors::RecordNotDestroyed)
      end
    end
  end

  it 'has a table name' do
    expect(Address.table_name).to eq 'dynamoid_tests_addresses'
  end

  context 'with namespace is empty' do
    def reload_address
      Object.send(:remove_const, 'Address') # rubocop:disable RSpec/RemoveConst
      load 'app/models/address.rb'
    end

    namespace = Dynamoid::Config.namespace

    before do
      reload_address
      Dynamoid.configure do |config|
        config.namespace = ''
      end
    end

    after do
      reload_address
      Dynamoid.configure do |config|
        config.namespace = namespace
      end
    end

    it 'does not add a namespace prefix to table names' do
      table_name = Address.table_name
      expect(Dynamoid::Config.namespace).to be_empty
      expect(table_name).to eq 'addresses'
    end
  end

  it 'deletes an item completely' do
    @user = User.create(name: 'Josh')
    @user.destroy

    expect(Dynamoid.adapter.read('dynamoid_tests_users', @user.id)).to be_nil
  end
end
