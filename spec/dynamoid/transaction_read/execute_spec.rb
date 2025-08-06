# frozen_string_literal: true

require 'spec_helper'

describe Dynamoid::TransactionRead, '.execute' do
  let(:klass) do
    new_class do
      field :name
    end
  end

  it 'returns model that are fetched within a specified block' do
    obj1 = klass.create!(name: 'Alex')
    obj2 = klass.create!(name: 'Michael')

    result = described_class.execute do |t|
      t.find klass, obj1.id
      t.find klass, obj2.id
    end

    expect(result).to eql([obj1, obj2])
  end
end
