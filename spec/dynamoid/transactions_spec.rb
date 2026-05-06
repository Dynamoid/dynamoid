# frozen_string_literal: true

require 'spec_helper'

describe Dynamoid::Transactions do
  let(:klass) do
    new_class do
      field :name
    end
  end

  before do
    klass.create_table
  end

  it 'supports Model.transaction with a block to start a write-only transaction' do
    user = klass.new(id: '1', name: 'Original')

    klass.transaction do |t|
      t.save(user)
    end

    expect(klass.find('1').name).to eq('Original')
  end

  it 'supports Model.transaction.writing to start a write-only transaction' do
    user = klass.new(id: '2', name: 'Writing')

    klass.transaction.writing do |t|
      t.save(user)
    end

    expect(klass.find('2').name).to eq('Writing')
  end

  it 'supports Model.transaction.reading to start a read-only transaction' do
    klass.create(id: '3', name: 'Reading')

    results = klass.transaction.reading do |t|
      t.find(klass, '3')
    end

    expect(results.first.name).to eq('Reading')
  end
end
