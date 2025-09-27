# frozen_string_literal: true

require 'spec_helper'
require 'fixtures/persistence'

RSpec.describe Dynamoid::Persistence do
  describe 'destroy' do
    # TODO: adopt test cases for the `delete` method

    let(:klass) do
      new_class do
        field :name
      end
    end

    let(:klass_with_composite_key) do
      new_class do
        range :age, :integer
        field :name
      end
    end

    it 'does not raise exception when model was concurrently deleted' do
      obj = klass.create
      obj2 = klass.find(obj.id)
      obj.delete
      expect(klass.exists?(obj.id)).to eql false

      obj2.destroy
      expect(obj2.destroyed?).to eql true
    end

    describe 'primary key validation' do
      context 'simple primary key' do
        it 'requires partition key to be specified' do
          obj = klass.create!(name: 'one')
          obj.id = nil

          expect { obj.destroy }.to raise_exception(Dynamoid::Errors::MissingHashKey)
        end
      end

      context 'composite key' do
        it 'requires partition key to be specified' do
          obj = klass_with_composite_key.create!(name: 'one', age: 1)
          obj.id = nil

          expect { obj.destroy }.to raise_exception(Dynamoid::Errors::MissingHashKey)
        end

        it 'requires sort key to be specified' do
          obj = klass_with_composite_key.create!(name: 'one', age: 1)
          obj.age = nil

          expect { obj.destroy }.to raise_exception(Dynamoid::Errors::MissingRangeKey)
        end
      end
    end

    describe 'callbacks' do
      it 'runs before_destroy callback' do
        klass_with_callback = new_class do
          before_destroy { print 'run before_destroy' }
        end

        obj = klass_with_callback.create

        expect { obj.destroy }.to output('run before_destroy').to_stdout
      end

      it 'runs after_destroy callback' do
        klass_with_callback = new_class do
          after_destroy { print 'run after_destroy' }
        end

        obj = klass_with_callback.create
        expect { obj.destroy }.to output('run after_destroy').to_stdout
      end

      it 'runs around_destroy callback' do
        klass_with_callback = new_class do
          around_destroy :around_destroy_callback

          def around_destroy_callback
            print 'start around_destroy'
            yield
            print 'finish around_destroy'
          end
        end

        obj = klass_with_callback.create

        expect { obj.destroy }.to output('start around_destroyfinish around_destroy').to_stdout
      end

      it 'aborts destroying and returns false if a before_destroy callback throws :abort' do
        if ActiveSupport.version < Gem::Version.new('5.0')
          skip "Rails 4.x and below don't support aborting with `throw :abort`"
        end

        klass = new_class do
          before_destroy { throw :abort }
        end
        obj = klass.create!

        result = nil
        expect {
          result = obj.destroy
        }.not_to change { klass.count }

        expect(result).to eql false
        # expect(obj.destroyed?).to eql false # FIXME
      end
    end

    context 'when table arn is specified', remove_constants: [:Payment] do
      it 'uses given table ARN in requests instead of a table name', config: { create_table_on_save: false } do
        # Create table manually because CreateTable doesn't accept ARN as a
        # table name. Add namespace to have this table removed automativally.
        table_name = :"#{Dynamoid::Config.namespace}_purchases"
        Dynamoid.adapter.create_table(table_name, :id)

        table = Dynamoid.adapter.describe_table(table_name)
        expect(table.arn).to be_present

        Payment = Class.new do # rubocop:disable Lint/ConstantDefinitionInBlock, RSpec/LeakyConstantDeclaration
          include Dynamoid::Document

          table arn: table.arn
        end

        payment = Payment.create!

        expect {
          payment.destroy
        }.to send_request_matching(:DeleteItem, { TableName: table.arn })
      end
    end
  end

  describe 'destroy!' do
    it 'aborts destroying and raises RecordNotDestroyed if a before_destroy callback throws :abort' do
      if ActiveSupport.version < Gem::Version.new('5.0')
        skip "Rails 4.x and below don't support aborting with `throw :abort`"
      end

      klass = new_class do
        before_destroy { throw :abort }
      end
      obj = klass.create!

      expect {
        expect {
          obj.destroy!
        }.to raise_error(Dynamoid::Errors::RecordNotDestroyed)
      }.not_to change { klass.count }

      # expect(obj.destroyed?).to eql false # FIXME
    end
  end
end
