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

  describe 'callbacks' do
    before do
      ScratchPad.clear
    end

    let(:klass) do
      new_class do
        field :name

        after_commit { ScratchPad << 'run after_commit' }
        after_rollback { ScratchPad << 'run after_rollback' }
      end
    end

    context 'transaction succeeds' do
      it 'runs #after_commit callbacks for each involved model' do
        klass.create_table

        t = described_class.new
        t.create klass
        t.create klass
        t.commit

        expect(ScratchPad.recorded).to eql ['run after_commit', 'run after_commit']
      end
    end

    context 'transaction fails' do
      before do
        ScratchPad.clear
      end

      it 'runs #after_rollback callbacks for each involved model' do
        # trigger transaction aborting by trying to create a new model with non-unique primary id
        existing = klass.create!(name: 'Alex')

        t = described_class.new
        t.create klass, name: 'Alex', id: existing.id
        t.create klass, name: 'Michael'

        expect {
          t.commit
        }.to raise_error(Aws::DynamoDB::Errors::TransactionCanceledException)

        expect(ScratchPad.recorded).to eql ['run after_rollback', 'run after_rollback']
      end
    end

    context 'transaction interrupted by exception in a callback' do
      before do
        ScratchPad.clear
      end

      it 'does not run #after_rollback callbacks for each involved model' do
        klass_with_exception = new_class do
          before_create { raise 'from a callback' }
        end

        t = described_class.new
        t.create klass

        expect {
          t.create klass_with_exception
        }.to raise_error('from a callback')

        expect(ScratchPad.recorded).to eql []
      end
    end
  end
end
