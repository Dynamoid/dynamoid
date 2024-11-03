# frozen_string_literal: true

require 'spec_helper'

describe Dynamoid::TransactionWrite, '#commit' do
  let(:klass) do
    new_class do
      field :name
    end
  end

  it 'persists changes' do
    klass.create_table
    transaction = described_class.new
    transaction.create klass
    transaction.create klass

    expect { transaction.commit }.to change(klass, :count).by(2)
  end
end
