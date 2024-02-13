# frozen_string_literal: true

require 'spec_helper'
require_relative 'context'

# Dynamoid.config.logger.level = :debug

describe Dynamoid::TransactionWrite, '.action' do
  include_context 'transaction_write'

  context 'incrementally builds' do
    it 'executes' do
      klass.create_table
      klass_with_composite_key.create_table
      transaction = described_class.new
      obj1 = transaction.create!(klass, { name: 'one' })
      obj2_id = SecureRandom.uuid
      transaction.upsert(klass_with_composite_key, { id: obj2_id, age: 2, name: 'two' })
      expect(klass).not_to exist(obj1.id)
      expect(klass).not_to exist(obj2_id)
      transaction.commit

      obj1_found = klass.find(obj1.id)
      obj2_found = klass_with_composite_key.find(obj2_id, range_key: 2)
      expect(obj1_found).to eql(obj1)
      expect(obj2_found.id).to eql(obj2_id)
      expect(obj1_found.name).to eql('one')
      expect(obj2_found.name).to eql('two')
    end
  end
end
