# frozen_string_literal: true

require 'spec_helper'
require 'fixtures/persistence'

RSpec.describe Dynamoid::Persistence do
  describe 'delete' do
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

    it 'does not raise exception when model does not exist' do
      klass = new_class
      obj = klass.create
      obj2 = klass.find(obj.id)
      obj.delete
      expect(klass.exists?(obj.id)).to eql false

      obj2.delete
      expect(obj2.destroyed?).to eql true
    end

    context 'with lock version' do
      let(:address) { Address.new }

      it 'deletes a record if lock version matches' do
        address.save!
        expect { address.delete }.not_to raise_error
      end

      it 'does not delete a record if lock version does not match' do
        address.save!
        a1 = address
        a2 = Address.find(address.id)

        a1.city = 'Seattle'
        a1.save!

        expect { a2.delete }.to raise_exception(Dynamoid::Errors::StaleObjectError)
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
  end
end
