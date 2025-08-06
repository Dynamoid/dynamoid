# frozen_string_literal: true

require 'spec_helper'

describe Dynamoid::TransactionRead, '#commit' do
  let(:klass) do
    new_class do
      field :name
    end
  end

  it 'returns found models' do
    obj1 = klass.create!(name: 'Alex')
    obj2 = klass.create!(name: 'Michael')

    transaction = described_class.new

    transaction.find klass, obj1.id
    transaction.find klass, obj2.id

    expect(transaction.commit).to eql([obj1, obj2])
  end
end
