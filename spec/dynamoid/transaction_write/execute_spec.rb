# frozen_string_literal: true

require 'spec_helper'

describe Dynamoid::TransactionWrite, '.execute' do
  let(:klass) do
    new_class do
      field :name
    end
  end

  it 'persists changes registered within a specified block' do
    klass.create_table

    expect {
      described_class.execute do |t|
        t.create klass
        t.create klass
      end
    }.to change(klass, :count).by(2)
  end

  describe 'callbacks' do
    context 'transaction succeeds' do
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

      describe '#create action' do
        it 'runs #after_commit callbacks for a model' do
          klass.create_table

          described_class.execute do |t|
            t.create klass
          end

          expect(ScratchPad.recorded).to eql ['run after_commit']
        end
      end

      describe '#destroy action' do
        it 'runs #after_commit callbacks for a model' do
          object = klass.create!

          described_class.execute do |t|
            t.destroy object
          end

          expect(ScratchPad.recorded).to eql ['run after_commit']
        end
      end

      describe '#save action' do
        it 'runs #after_commit callbacks for a model' do
          klass.create_table
          object = klass.new

          described_class.execute do |t|
            t.save object
          end

          expect(ScratchPad.recorded).to eql ['run after_commit']
        end
      end

      describe '#update_attributes action' do
        it 'runs #after_commit callbacks for a model' do
          object = klass.create!

          described_class.execute do |t|
            t.update_attributes object, name: 'Alex'
          end

          expect(ScratchPad.recorded).to eql ['run after_commit']
        end
      end
    end

    context 'transaction interrupted by user exception' do
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

      it 'runs #after_rollback callbacks for each involved model and re-raises exception' do
        klass_with_exception = new_class do
          before_create { raise 'from a callback' }
        end

        expect {
          described_class.execute do |t|
            t.create klass
            raise 'from a transaction'
          end
        }.to raise_error('from a transaction')

        expect(ScratchPad.recorded).to eql ['run after_rollback']
      end

      # Test here that #after_rollback callbacks are called for all the actions that run callbacks.
      # Do not test such actions in specs for the #commit method because it is excessive.
      describe '#create action' do
        it 'runs #after_rollback callbacks for a model' do
          expect {
            described_class.execute do |t|
              t.create klass
              raise 'from a transaction'
            end
          }.to raise_error('from a transaction')

          expect(ScratchPad.recorded).to eql ['run after_rollback']
        end
      end

      describe '#destroy action' do
        it 'runs #after_rollback callbacks for a model' do
          object = klass.create!

          expect {
            described_class.execute do |t|
              t.destroy object
              raise 'from a transaction'
            end
          }.to raise_error('from a transaction')

          expect(ScratchPad.recorded).to eql ['run after_rollback']
        end
      end

      describe '#save action' do
        it 'runs #after_rollback callbacks for a model' do
          object = klass.new

          expect {
            described_class.execute do |t|
              t.save object
              raise 'from a transaction'
            end
          }.to raise_error('from a transaction')

          expect(ScratchPad.recorded).to eql ['run after_rollback']
        end
      end

      describe '#update_attributes action' do
        it 'runs #after_rollback callbacks for a model' do
          object = klass.create!

          expect {
            described_class.execute do |t|
              t.update_attributes object, name: 'Alex'
              raise 'from a transaction'
            end
          }.to raise_error('from a transaction')

          expect(ScratchPad.recorded).to eql ['run after_rollback']
        end
      end
    end

    context 'transaction interrupted by Dynamoid::Error::Rollback exception' do
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

      it 'runs #after_rollback callbacks for each involved model and does not re-raise exception' do
        described_class.execute do |t|
          t.create klass
          raise Dynamoid::Errors::Rollback
        end

        expect(ScratchPad.recorded).to eql ['run after_rollback']
      end
    end
  end
end
