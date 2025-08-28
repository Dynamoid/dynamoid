# frozen_string_literal: true

require 'spec_helper'

describe Dynamoid::Indexes do
  let(:klass_with_gsi) do
    new_class(class_name: 'Ferret') do
      field :name
      field :age, :number
      global_secondary_index hash_key: :name, range_key: :age, projected_attributes: :all, name: 'str_num'
    end
  end

  before do
    klass_with_gsi.create_table
  end

  describe '.global_secondary_index' do
    it 'can save in transaction' do
      doc = klass_with_gsi.new(name: 'abc', age: 1)
      Dynamoid::TransactionWrite.execute do |txn|
        txn.save! doc
      end
      expect(doc).to be_persisted
    end

    it 'can create in transaction' do
      doc = klass_with_gsi.new
      doc.name = 'abc'
      doc.age = nil
      Dynamoid::TransactionWrite.execute do |txn|
        txn.save! doc
      end
      expect(doc).to be_persisted
    end

    it 'can update in transaction' do
      doc = klass_with_gsi.new
      doc.name = 'abc'
      doc.age = 1
      doc.save!
      doc.age = nil
      Dynamoid::TransactionWrite.execute do |txn|
        txn.save! doc
      end
      expect(doc).to be_persisted
    end

    it 'can update_field in transaction' do
      doc = klass_with_gsi.new
      doc.name = 'abc'
      doc.age = 1
      doc.save!
      Dynamoid::TransactionWrite.execute do |txn|
        txn.update_fields klass_with_gsi, doc.id, age: nil
      end
      expect(doc).to be_persisted
    end

    it 'can upsert in transaction' do
      doc = klass_with_gsi.new
      doc.name = 'abc'
      doc.age = 1
      doc.save!
      Dynamoid::TransactionWrite.execute do |txn|
        txn.upsert klass_with_gsi, doc.id, age: nil
      end
      expect(doc).to be_persisted
      expect(doc.reload.age).to be_nil
    end

    # context 'store_attribute_with_nil_value = true', config: { store_attribute_with_nil_value: true } do
    #   it 'can set gsi field to nil' do
    #     doc = klass_with_gsi.new
    #     doc.name = 'abc'
    #     doc.age = 1
    #     doc.save!
    #     doc.age = nil
    #     doc.save!
    #   end
    # end
  end
end
