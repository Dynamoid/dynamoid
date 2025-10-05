# frozen_string_literal: true

require 'spec_helper'
require 'fixtures/persistence'

RSpec.describe Dynamoid::Persistence do
  describe '#destroy' do
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

    it 'deletes an item' do
      klass = new_class
      obj = klass.create!

      expect { obj.destroy }.to change { klass.exists? obj.id }.from(true).to(false)
    end

    it 'returns self' do
      klass = new_class
      obj = klass.create!

      expect(obj.destroy).to eq obj
    end

    it 'forces #destroyed? predicate to return true' do
      klass = new_class
      obj = klass.create!

      expect { obj.destroy }.to change(obj, :destroyed?).from(nil).to(true)
    end

    it 'uses dumped value of partition key to delete item' do
      klass = new_class(partition_key: { name: :published_on, type: :date })

      obj = klass.create!(published_on: '2018-10-07'.to_date)

      expect { obj.destroy }.to change {
        klass.where(published_on: obj.published_on).first
      }.to(nil)
    end

    it 'uses dumped value of sort key to delete item' do
      klass = new_class do
        range :activated_on, :date
      end

      obj = klass.create!(activated_on: Date.today)

      expect { obj.destroy }.to change {
        klass.where(id: obj.id, activated_on: obj.activated_on).first
      }.to(nil)
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

    context 'with lock version' do
      let(:address) { Address.new }

      it 'deletes a record if lock version matches' do
        address.save!

        expect {
          address.destroy
        }.to change { Address.where(id: address.id).first }.to(nil)
      end

      it 'does not delete a record if lock version does not match' do
        address.save!
        a1 = address
        a2 = Address.find(address.id)

        a1.city = 'Seattle'
        a1.save!

        expect { a2.destroy }.to raise_exception(Dynamoid::Errors::StaleObjectError)
        expect(a2.destroyed?).to eql(false) # FIXME
      end

      it 'uses the correct lock_version even if it is modified' do
        address.save!
        a1 = address
        a1.lock_version = 100

        expect {
          address.destroy
        }.to change { Address.where(id: address.id).first }.to(nil)
      end
    end

    context 'when model has associations' do
      context 'when belongs_to association' do
        context 'when has_many on the other side' do
          let!(:source_model) { User.create }
          let!(:target_model) { source_model.camel_case.create }

          it 'disassociates self' do
            expect do
              source_model.destroy
            end.to change { CamelCase.find(target_model.id).users.target }.from([source_model]).to([])
          end

          it 'updates cached ids list in associated model' do
            source_model.destroy
            expect(CamelCase.find(target_model.id).users_ids).to eq nil
          end

          it 'behaves correctly when associated model is linked with several models' do
            source_model2 = User.create
            target_model.users << source_model2

            expect(CamelCase.find(target_model.id).users.target).to contain_exactly(source_model, source_model2)
            source_model.destroy
            expect(CamelCase.find(target_model.id).users.target).to contain_exactly(source_model2)
            expect(CamelCase.find(target_model.id).users_ids).to eq [source_model2.id].to_set
          end

          it 'does not raise exception when foreign key is broken' do
            source_model.update_attributes!(camel_case_ids: ['fake_id'])

            expect { source_model.destroy }.not_to raise_error
            expect(CamelCase.find(target_model.id).users.target).to eq []
          end
        end

        context 'when has_one on the other side' do
          let!(:source_model) { Sponsor.create }
          let!(:target_model) { source_model.camel_case.create }

          it 'disassociates self' do
            expect do
              source_model.destroy
            end.to change { CamelCase.find(target_model.id).sponsor.target }.from(source_model).to(nil)
          end

          it 'updates cached ids list in associated model' do
            source_model.destroy
            expect(CamelCase.find(target_model.id).sponsor_ids).to eq nil
          end

          it 'does not raise exception when foreign key is broken' do
            source_model.update_attributes!(camel_case_ids: ['fake_id'])

            expect { source_model.destroy }.not_to raise_error
            expect(CamelCase.find(target_model.id).sponsor.target).to eq nil
          end
        end
      end

      context 'when has_many association' do
        let!(:source_model) { User.create }
        let!(:target_model) { source_model.books.create }

        it 'disassociates self' do
          expect do
            source_model.destroy
          end.to change { Magazine.find(target_model.title).owner.target }.from(source_model).to(nil)
        end

        it 'updates cached ids list in associated model' do
          source_model.destroy
          expect(Magazine.find(target_model.title).owner_ids).to eq nil
        end

        it 'does not raise exception when cached foreign key is broken' do
          books_ids_new = source_model.books_ids + ['fake_id']
          source_model.update_attributes!(books_ids: books_ids_new)

          expect { source_model.destroy }.not_to raise_error
          expect(Magazine.find(target_model.title).owner).to eq nil
        end
      end

      context 'when has_one association' do
        let!(:source_model) { User.create }
        let!(:target_model) { source_model.monthly.create }

        it 'disassociates self' do
          expect do
            source_model.destroy
          end.to change { Subscription.find(target_model.id).customer.target }.from(source_model).to(nil)
        end

        it 'updates cached ids list in associated model' do
          source_model.destroy
          expect(Subscription.find(target_model.id).customer_ids).to eq nil
        end

        it 'does not raise exception when cached foreign key is broken' do
          source_model.update_attributes!(monthly_ids: ['fake_id'])

          expect { source_model.destroy }.not_to raise_error
        end
      end

      context 'when has_and_belongs_to_many association' do
        let!(:source_model) { User.create }
        let!(:target_model) { source_model.subscriptions.create }

        it 'disassociates self' do
          expect do
            source_model.destroy
          end.to change { Subscription.find(target_model.id).users.target }.from([source_model]).to([])
        end

        it 'updates cached ids list in associated model' do
          source_model.destroy
          expect(Subscription.find(target_model.id).users_ids).to eq nil
        end

        it 'behaves correctly when associated model is linked with several models' do
          source_model2 = User.create
          target_model.users << source_model2

          expect(Subscription.find(target_model.id).users.target).to contain_exactly(source_model, source_model2)
          source_model.destroy
          expect(Subscription.find(target_model.id).users.target).to contain_exactly(source_model2)
          expect(Subscription.find(target_model.id).users_ids).to eq [source_model2.id].to_set
        end

        it 'does not raise exception when foreign key is broken' do
          subscriptions_ids_new = source_model.subscriptions_ids + ['fake_id']
          source_model.update_attributes!(subscriptions_ids: subscriptions_ids_new)

          expect { source_model.destroy }.not_to raise_error
          expect(Subscription.find(target_model.id).users_ids).to eq nil
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
        expect(obj.destroyed?).to eql nil
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

  describe '#destroy!' do
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

      expect(obj.destroyed?).to eql nil
    end
  end
end
