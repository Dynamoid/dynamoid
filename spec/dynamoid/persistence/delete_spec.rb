# frozen_string_literal: true

require 'spec_helper'
require 'fixtures/persistence'

RSpec.describe Dynamoid::Persistence do
  describe '.delete' do
    let(:klass_with_composite_key) do
      new_class do
        range :age, :integer
        field :name
      end
    end

    it 'deletes an item' do
      klass = new_class
      obj = klass.create!

      expect { klass.delete(obj.id) }.to change { klass.exists? obj.id }.from(true).to(false)
    end

    it 'deletes multiple items when given multiple partition keys' do
      klass = new_class
      obj1 = klass.create!
      obj2 = klass.create!

      expect {
        expect {
          klass.delete([obj1.id, obj2.id])
        }.to change { klass.where(id: obj1.id).first }.to(nil)
      }.to change { klass.where(id: obj2.id).first }.to(nil)
    end

    it 'deletes multiple items when given multiple partition and sort keys' do
      obj1 = klass_with_composite_key.create!(age: 1)
      obj2 = klass_with_composite_key.create!(age: 2)

      expect {
        expect {
          klass_with_composite_key.delete([[obj1.id, obj1.age], [obj2.id, obj2.age]])
        }.to change { klass_with_composite_key.where(id: obj1.id, age: obj1.age).first }.to(nil)
      }.to change { klass_with_composite_key.where(id: obj2.id, age: obj2.age).first }.to(nil)
    end

    it 'uses dumped value of partition key to delete item' do
      klass = new_class(partition_key: { name: :published_on, type: :date })

      obj = klass.create!(published_on: '2018-10-07'.to_date)

      expect {
        klass.delete(obj.published_on)
      }.to change { klass.where(published_on: obj.published_on).first }.to(nil)
    end

    it 'uses dumped value of partition key to delete item when given multiple primary keys' do
      klass = new_class(partition_key: { name: :published_on, type: :date })

      obj1 = klass.create!(published_on: '2018-10-07'.to_date)
      obj2 = klass.create!(published_on: '2018-10-13'.to_date)

      expect {
        expect {
          klass.delete([obj1.published_on, obj2.published_on])
        }.to change { klass.where(published_on: obj1.published_on).first }.to(nil)
      }.to change { klass.where(published_on: obj2.published_on).first }.to(nil)
    end

    it 'uses dumped value of sort key to delete item' do
      klass = new_class do
        range :activated_on, :date
      end

      obj = klass.create!(activated_on: Date.today)

      expect {
        klass.delete(obj.id, obj.activated_on)
      }.to change { klass.where(id: obj.id, activated_on: obj.activated_on).first }.to(nil)
    end

    it 'uses dumped value of sort key to delete item when given multiple primary keys' do
      klass = new_class do
        range :activated_on, :date
      end

      obj1 = klass.create!(activated_on: Date.today)
      obj2 = klass.create!(activated_on: Date.tomorrow)

      expect {
        expect {
          klass.delete([[obj1.id, obj1.activated_on], [obj2.id, obj2.activated_on]])
        }.to change { klass.where(id: obj1.id, activated_on: obj1.activated_on).first }.to(nil)
      }.to change { klass.where(id: obj2.id, activated_on: obj2.activated_on).first }.to(nil)
    end

    it 'does not raise exception when model was concurrently deleted' do
      klass = new_class
      klass.create_table

      expect(klass.delete('not-existing-id')).to eql(nil)
    end

    describe 'primary key validation' do
      context 'simple primary key' do
        it 'requires partition key to be specified' do
          klass = new_class
          expect { klass.delete(nil) }.to raise_exception(Dynamoid::Errors::MissingHashKey)
          expect { klass.delete }.to raise_exception(Dynamoid::Errors::MissingHashKey)
        end
      end

      context 'composite key' do
        it 'requires partition key to be specified' do
          expect { klass_with_composite_key.delete(nil, 1) }.to raise_exception(Dynamoid::Errors::MissingHashKey)
        end

        it 'requires partition key to be specified when given multiple primary keys' do
          expect { klass_with_composite_key.delete([nil]) }.to raise_exception(Dynamoid::Errors::MissingHashKey)
        end

        it 'requires sort key to be specified' do
          expect { klass_with_composite_key.delete('abc', nil) }.to raise_exception(Dynamoid::Errors::MissingRangeKey)
          expect { klass_with_composite_key.delete('abc') }.to raise_exception(Dynamoid::Errors::MissingRangeKey)
        end

        it 'requires sort key to be specified when given multiple primary keys' do
          expect { klass_with_composite_key.delete([['abc', nil]]) }.to raise_exception(Dynamoid::Errors::MissingRangeKey)
          expect { klass_with_composite_key.delete([['abc']]) }.to raise_exception(Dynamoid::Errors::MissingRangeKey)
        end
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
          Payment.delete(payment.id)
        }.to send_request_matching(:DeleteItem, { TableName: table.arn })
      end
    end
  end

  describe '#delete' do
    let(:klass_with_composite_key) do
      new_class do
        range :age, :integer
        field :name
      end
    end

    it 'deletes an item' do
      klass = new_class
      obj = klass.create

      expect { obj.delete }.to change { klass.exists? obj.id }.from(true).to(false)
    end

    it 'returns self' do
      klass = new_class
      obj = klass.create

      expect(obj.delete).to eq obj
    end

    it 'forces #destroyed? predicate to return true' do
      klass = new_class
      obj = klass.create!

      expect { obj.delete }.to change(obj, :destroyed?).from(nil).to(true)
    end

    it 'uses dumped value of partition key to delete item' do
      klass = new_class(partition_key: { name: :published_on, type: :date })

      obj = klass.create!(published_on: '2018-10-07'.to_date)

      expect { obj.delete }.to change {
        klass.where(published_on: obj.published_on).first
      }.to(nil)
    end

    it 'uses dumped value of sort key to delete item' do
      klass = new_class do
        range :activated_on, :date
      end

      obj = klass.create!(activated_on: Date.today)

      expect { obj.delete }.to change {
        klass.where(id: obj.id, activated_on: obj.activated_on).first
      }.to(nil)
    end

    it 'does not raise exception when model was concurrently deleted' do
      klass = new_class
      obj = klass.create
      obj2 = klass.find(obj.id)
      obj.delete
      expect(klass.exists?(obj.id)).to eql false

      obj2.delete
      expect(obj2.destroyed?).to eql true
    end

    describe 'primary key validation' do
      context 'simple primary key' do
        it 'requires partition key to be specified' do
          klass = new_class
          obj = klass.create!
          obj.id = nil

          expect { obj.delete }.to raise_exception(Dynamoid::Errors::MissingHashKey)
        end
      end

      context 'composite key' do
        it 'requires partition key to be specified' do
          obj = klass_with_composite_key.create!(age: 1)
          obj.id = nil

          expect { obj.delete }.to raise_exception(Dynamoid::Errors::MissingHashKey)
        end

        it 'requires sort key to be specified' do
          obj = klass_with_composite_key.create!(age: 1)
          obj.age = nil

          expect { obj.delete }.to raise_exception(Dynamoid::Errors::MissingRangeKey)
        end
      end
    end

    context 'with lock version' do
      let(:address) { Address.new }

      it 'deletes a record if lock version matches' do
        address.save!

        expect { address.delete }.to change { Address.exists? address.id }.from(true).to(false)
      end

      it 'does not delete a record if lock version does not match' do
        address.save!
        a1 = address
        a2 = Address.find(address.id)

        a1.city = 'Seattle'
        a1.save!

        expect { a2.delete }.to raise_error(Dynamoid::Errors::StaleObjectError)
        expect(a2.destroyed?).to eql false
      end

      it 'uses the correct lock_version even if it is modified' do
        address.save!
        a1 = address
        a1.lock_version = 100

        expect { a1.delete }.not_to raise_error
      end
    end

    context 'when model has associations' do
      context 'when belongs_to association' do
        context 'when has_many on the other side' do
          let!(:source_model) { User.create }
          let!(:target_model) { source_model.camel_case.create }

          it 'disassociates self' do
            expect do
              source_model.delete
            end.to change { CamelCase.find(target_model.id).users.target }.from([source_model]).to([])
          end

          it 'updates cached ids list in associated model' do
            source_model.delete
            expect(CamelCase.find(target_model.id).users_ids).to eq nil
          end

          it 'behaves correctly when associated model is linked with several models' do
            source_model2 = User.create
            target_model.users << source_model2

            expect(CamelCase.find(target_model.id).users.target).to contain_exactly(source_model, source_model2)
            source_model.delete
            expect(CamelCase.find(target_model.id).users.target).to contain_exactly(source_model2)
            expect(CamelCase.find(target_model.id).users_ids).to eq [source_model2.id].to_set
          end

          it 'does not raise exception when foreign key is broken' do
            source_model.update_attributes!(camel_case_ids: ['fake_id'])

            expect { source_model.delete }.not_to raise_error
            expect(CamelCase.find(target_model.id).users.target).to eq []
          end
        end

        context 'when has_one on the other side' do
          let!(:source_model) { Sponsor.create }
          let!(:target_model) { source_model.camel_case.create }

          it 'disassociates self' do
            expect do
              source_model.delete
            end.to change { CamelCase.find(target_model.id).sponsor.target }.from(source_model).to(nil)
          end

          it 'updates cached ids list in associated model' do
            source_model.delete
            expect(CamelCase.find(target_model.id).sponsor_ids).to eq nil
          end

          it 'does not raise exception when foreign key is broken' do
            source_model.update_attributes!(camel_case_ids: ['fake_id'])

            expect { source_model.delete }.not_to raise_error
            expect(CamelCase.find(target_model.id).sponsor.target).to eq nil
          end
        end
      end

      context 'when has_many association' do
        let!(:source_model) { User.create }
        let!(:target_model) { source_model.books.create }

        it 'disassociates self' do
          expect do
            source_model.delete
          end.to change { Magazine.find(target_model.title).owner.target }.from(source_model).to(nil)
        end

        it 'updates cached ids list in associated model' do
          source_model.delete
          expect(Magazine.find(target_model.title).owner_ids).to eq nil
        end

        it 'does not raise exception when cached foreign key is broken' do
          books_ids_new = source_model.books_ids + ['fake_id']
          source_model.update_attributes!(books_ids: books_ids_new)

          expect { source_model.delete }.not_to raise_error
          expect(Magazine.find(target_model.title).owner).to eq nil
        end
      end

      context 'when has_one association' do
        let!(:source_model) { User.create }
        let!(:target_model) { source_model.monthly.create }

        it 'disassociates self' do
          expect do
            source_model.delete
          end.to change { Subscription.find(target_model.id).customer.target }.from(source_model).to(nil)
        end

        it 'updates cached ids list in associated model' do
          source_model.delete
          expect(Subscription.find(target_model.id).customer_ids).to eq nil
        end

        it 'does not raise exception when cached foreign key is broken' do
          source_model.update_attributes!(monthly_ids: ['fake_id'])

          expect { source_model.delete }.not_to raise_error
        end
      end

      context 'when has_and_belongs_to_many association' do
        let!(:source_model) { User.create }
        let!(:target_model) { source_model.subscriptions.create }

        it 'disassociates self' do
          expect do
            source_model.delete
          end.to change { Subscription.find(target_model.id).users.target }.from([source_model]).to([])
        end

        it 'updates cached ids list in associated model' do
          source_model.delete
          expect(Subscription.find(target_model.id).users_ids).to eq nil
        end

        it 'behaves correctly when associated model is linked with several models' do
          source_model2 = User.create
          target_model.users << source_model2

          expect(Subscription.find(target_model.id).users.target).to contain_exactly(source_model, source_model2)
          source_model.delete
          expect(Subscription.find(target_model.id).users.target).to contain_exactly(source_model2)
          expect(Subscription.find(target_model.id).users_ids).to eq [source_model2.id].to_set
        end

        it 'does not raise exception when foreign key is broken' do
          subscriptions_ids_new = source_model.subscriptions_ids + ['fake_id']
          source_model.update_attributes!(subscriptions_ids: subscriptions_ids_new)

          expect { source_model.delete }.not_to raise_error
          expect(Subscription.find(target_model.id).users_ids).to eq nil
        end
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
          payment.delete
        }.to send_request_matching(:DeleteItem, { TableName: table.arn })
      end
    end
  end
end
