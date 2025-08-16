# frozen_string_literal: true

require 'spec_helper'
require 'fixtures/persistence'

RSpec.describe Dynamoid::Persistence do
  describe '.create_table' do
    it 'creates a table' do
      klass = new_class

      tables = Dynamoid.adapter.list_tables
      expect(tables.include?(klass.table_name)).to eq false

      klass.create_table

      tables = Dynamoid.adapter.list_tables
      expect(tables.include?(klass.table_name)).to eq true
    end

    it 'returns self' do
      klass = new_class
      expect(klass.create_table).to eq(klass)
    end

    describe 'partition key attribute type' do
      it 'maps :string to String' do
        klass = new_class(partition_key: { name: :id, type: :string })
        klass.create_table
        expect(raw_attribute_types(klass.table_name)['id']).to eql('S')
      end

      it 'maps :integer to Number' do
        klass = new_class(partition_key: { name: :id, type: :integer })
        klass.create_table
        expect(raw_attribute_types(klass.table_name)['id']).to eql('N')
      end

      it 'maps :number to Number' do
        klass = new_class(partition_key: { name: :id, type: :number })
        klass.create_table
        expect(raw_attribute_types(klass.table_name)['id']).to eql('N')
      end

      describe ':datetime' do
        it 'maps :datetime to Number' do
          klass = new_class(partition_key: { name: :id, type: :datetime })
          klass.create_table
          expect(raw_attribute_types(klass.table_name)['id']).to eql('N')
        end

        it 'maps :datetime to String if field option :store_as_string is true' do
          klass = new_class(partition_key: { name: :id, type: :datetime, options: { store_as_string: true } })
          klass.create_table
          expect(raw_attribute_types(klass.table_name)['id']).to eql('S')
        end

        it 'maps :datetime to Number if field option :store_as_string is false' do
          klass = new_class(partition_key: { name: :id, type: :datetime, options: { store_as_string: false } })
          klass.create_table
          expect(raw_attribute_types(klass.table_name)['id']).to eql('N')
        end

        context 'field option :store_as_string is nil' do
          it 'maps :datetime to String if :store_datetime_as_string is true', config: { store_datetime_as_string: true } do
            klass = new_class(partition_key: { name: :id, type: :datetime, options: { store_as_string: nil } })
            klass.create_table
            expect(raw_attribute_types(klass.table_name)['id']).to eql('S')
          end

          it 'maps :datetime to Number if :store_datetime_as_string is false', config: { store_datetime_as_string: false } do
            klass = new_class(partition_key: { name: :id, type: :datetime, options: { store_as_string: nil } })
            klass.create_table
            expect(raw_attribute_types(klass.table_name)['id']).to eql('N')
          end
        end
      end

      describe ':date' do
        it 'maps :date to Number' do
          klass = new_class(partition_key: { name: :id, type: :date })
          klass.create_table
          expect(raw_attribute_types(klass.table_name)['id']).to eql('N')
        end

        it 'maps :date to String if field option :store_as_string is true' do
          klass = new_class(partition_key: { name: :id, type: :date, options: { store_as_string: true } })
          klass.create_table
          expect(raw_attribute_types(klass.table_name)['id']).to eql('S')
        end

        it 'maps :date to Number if field option :store_as_string is false' do
          klass = new_class(partition_key: { name: :id, type: :date, options: { store_as_string: false } })
          klass.create_table
          expect(raw_attribute_types(klass.table_name)['id']).to eql('N')
        end

        context 'field option :store_as_string is nil' do
          it 'maps :date to String if :store_date_as_string is true', config: { store_date_as_string: true } do
            klass = new_class(partition_key: { name: :id, type: :date, options: { store_as_string: nil } })
            klass.create_table
            expect(raw_attribute_types(klass.table_name)['id']).to eql('S')
          end

          it 'maps :date to Number if :store_date_as_string is false', config: { store_date_as_string: false } do
            klass = new_class(partition_key: { name: :id, type: :date, options: { store_as_string: nil } })
            klass.create_table
            expect(raw_attribute_types(klass.table_name)['id']).to eql('N')
          end
        end
      end

      it 'maps :serialized to String' do
        klass = new_class(partition_key: { name: :id, type: :serialized })
        klass.create_table
        expect(raw_attribute_types(klass.table_name)['id']).to eql('S')
      end

      describe 'custom type' do
        it 'maps custom type to String by default' do
          klass = new_class(partition_key: { name: :id, type: PersistenceSpec::User })
          klass.create_table
          expect(raw_attribute_types(klass.table_name)['id']).to eql('S')
        end

        it 'uses specified type if .dynamoid_field_type method declared' do
          klass = new_class(partition_key: { name: :id, type: PersistenceSpec::UserWithAge })
          klass.create_table
          expect(raw_attribute_types(klass.table_name)['id']).to eql('N')
        end
      end

      it 'does not support :array' do
        klass = new_class(partition_key: { name: :id, type: :array })
        expect { klass.create_table }.to raise_error(
          Dynamoid::Errors::UnsupportedKeyType, 'array cannot be used as a type of table key attribute'
        )
      end

      it 'does not support :set' do
        klass = new_class(partition_key: { name: :id, type: :set })
        expect { klass.create_table }.to raise_error(
          Dynamoid::Errors::UnsupportedKeyType, 'set cannot be used as a type of table key attribute'
        )
      end

      it 'does not support :raw' do
        klass = new_class(partition_key: { name: :id, type: :raw })
        expect { klass.create_table }.to raise_error(
          Dynamoid::Errors::UnsupportedKeyType, 'raw cannot be used as a type of table key attribute'
        )
      end

      it 'does not support :boolean' do
        klass = new_class(partition_key: { name: :id, type: :boolean })
        expect { klass.create_table }.to raise_error(
          Dynamoid::Errors::UnsupportedKeyType, 'boolean cannot be used as a type of table key attribute'
        )
      end
    end

    describe 'sort key attribute type' do
      it 'maps :string to String' do
        klass = new_class do
          range :prop, :string
        end
        klass.create_table

        expect(raw_attribute_types(klass.table_name)['prop']).to eql('S')
      end

      it 'maps :integer to Number' do
        klass = new_class do
          range :prop, :integer
        end
        klass.create_table

        expect(raw_attribute_types(klass.table_name)['prop']).to eql('N')
      end

      it 'maps :number to Number' do
        klass = new_class do
          range :prop, :number
        end
        klass.create_table

        expect(raw_attribute_types(klass.table_name)['prop']).to eql('N')
      end

      describe ':datetime' do
        it 'maps :datetime to Number' do
          klass = new_class do
            range :prop, :datetime
          end
          klass.create_table

          expect(raw_attribute_types(klass.table_name)['prop']).to eql('N')
        end

        it 'maps :datetime to String if field option :store_as_string is true' do
          klass = new_class do
            range :prop, :datetime, store_as_string: true
          end
          klass.create_table

          expect(raw_attribute_types(klass.table_name)['prop']).to eql('S')
        end

        it 'maps :datetime to Number if field option :store_as_string is false' do
          klass = new_class do
            range :prop, :datetime, store_as_string: false
          end
          klass.create_table

          expect(raw_attribute_types(klass.table_name)['prop']).to eql('N')
        end

        context 'field option :store_as_string is nil' do
          it 'maps :datetime to String if :store_datetime_as_string is true', config: { store_datetime_as_string: true } do
            klass = new_class do
              range :prop, :datetime, store_as_string: nil
            end
            klass.create_table

            expect(raw_attribute_types(klass.table_name)['prop']).to eql('S')
          end

          it 'maps :datetime to Number if :store_datetime_as_string is false', config: { store_datetime_as_string: false } do
            klass = new_class do
              range :prop, :datetime, store_as_string: nil
            end
            klass.create_table

            expect(raw_attribute_types(klass.table_name)['prop']).to eql('N')
          end
        end
      end

      describe ':date' do
        it 'maps :date to Number' do
          klass = new_class do
            range :prop, :date
          end
          klass.create_table

          expect(raw_attribute_types(klass.table_name)['prop']).to eql('N')
        end

        it 'maps :date to String if field option :store_as_string is true' do
          klass = new_class do
            range :prop, :date, store_as_string: true
          end
          klass.create_table

          expect(raw_attribute_types(klass.table_name)['prop']).to eql('S')
        end

        it 'maps :date to Number if field option :store_as_string is false' do
          klass = new_class do
            range :prop, :date, store_as_string: false
          end
          klass.create_table

          expect(raw_attribute_types(klass.table_name)['prop']).to eql('N')
        end

        context 'field option :store_as_string is nil' do
          it 'maps :date to String if :store_date_as_string is true', config: { store_date_as_string: true } do
            klass = new_class do
              range :prop, :date, store_as_string: nil
            end
            klass.create_table

            expect(raw_attribute_types(klass.table_name)['prop']).to eql('S')
          end

          it 'maps :date to Number if :store_date_as_string is false', config: { store_date_as_string: false } do
            klass = new_class do
              range :prop, :date, store_as_string: nil
            end
            klass.create_table

            expect(raw_attribute_types(klass.table_name)['prop']).to eql('N')
          end
        end
      end

      it 'maps :serialized to String' do
        klass = new_class do
          range :prop, :serialized
        end
        klass.create_table

        expect(raw_attribute_types(klass.table_name)['prop']).to eql('S')
      end

      describe 'custom type' do
        it 'maps custom type to String by default' do
          klass = new_class(sort_key_type: PersistenceSpec::User) do |options|
            range :prop, options[:sort_key_type]
          end
          klass.create_table

          expect(raw_attribute_types(klass.table_name)['prop']).to eql('S')
        end

        it 'uses specified type if .dynamoid_field_type method declared' do
          klass = new_class(sort_key_type: PersistenceSpec::UserWithAge) do |options|
            range :prop, options[:sort_key_type]
          end
          klass.create_table

          expect(raw_attribute_types(klass.table_name)['prop']).to eql('N')
        end
      end

      it 'does not support :array' do
        klass = new_class do
          range :prop, :array
        end

        expect { klass.create_table }.to raise_error(
          Dynamoid::Errors::UnsupportedKeyType, 'array cannot be used as a type of table key attribute'
        )
      end

      it 'does not support :set' do
        klass = new_class do
          range :prop, :set
        end

        expect { klass.create_table }.to raise_error(
          Dynamoid::Errors::UnsupportedKeyType, 'set cannot be used as a type of table key attribute'
        )
      end

      it 'does not support :raw' do
        klass = new_class do
          range :prop, :raw
        end

        expect { klass.create_table }.to raise_error(
          Dynamoid::Errors::UnsupportedKeyType, 'raw cannot be used as a type of table key attribute'
        )
      end

      it 'does not support :boolean' do
        klass = new_class do
          range :prop, :boolean
        end

        expect { klass.create_table }.to raise_error(
          Dynamoid::Errors::UnsupportedKeyType, 'boolean cannot be used as a type of table key attribute'
        )
      end
    end

    describe 'expiring (Time To Live)' do
      let(:class_with_expiration) do
        new_class do
          table expires: { field: :ttl, after: 60 }
          field :ttl, :integer
        end
      end

      it 'sets up TTL for table' do
        expect(Dynamoid.adapter).to receive(:update_time_to_live)
          .with(class_with_expiration.table_name, :ttl)
          .and_call_original

        class_with_expiration.create_table
      end

      it 'sets up TTL for table with specified table_name' do
        table_name = "#{class_with_expiration.table_name}_alias"

        expect(Dynamoid.adapter).to receive(:update_time_to_live)
          .with(table_name, :ttl)
          .and_call_original

        class_with_expiration.create_table(table_name: table_name)
      end
    end

    describe 'capacity mode' do
      # when capacity mode is PROVISIONED DynamoDB returns billing_mode_summary=nil
      let(:table_description) { Dynamoid.adapter.adapter.send(:describe_table, model.table_name) }
      let(:billing_mode)      { table_description.schema.billing_mode_summary&.billing_mode }

      before do
        model.create_table
      end

      context 'when global config option capacity_mode=on_demand', config: { capacity_mode: :on_demand } do
        context 'when capacity_mode=provisioned in table' do
          let(:model) do
            new_class do
              table capacity_mode: :provisioned
            end
          end

          it 'creates table with provisioned capacity mode' do
            expect(billing_mode).to eq nil # it means 'PROVISIONED'
          end
        end

        context 'when capacity_mode not set in table' do
          let(:model) do
            new_class do
              table capacity_mode: nil
            end
          end

          it 'creates table with on-demand capacity mode' do
            expect(billing_mode).to eq 'PAY_PER_REQUEST'
          end
        end
      end

      context 'when global config option capacity_mode=provisioned', config: { capacity_mode: :provisioned } do
        context 'when capacity_mode=on_demand in table' do
          let(:model) do
            new_class do
              table capacity_mode: :on_demand
            end
          end

          it 'creates table with on-demand capacity mode' do
            expect(billing_mode).to eq 'PAY_PER_REQUEST'
          end
        end

        context 'when capacity_mode not set in table' do
          let(:model) do
            new_class do
              table capacity_mode: nil
            end
          end

          it 'creates table with provisioned capacity mode' do
            expect(billing_mode).to eq nil # it means 'PROVISIONED'
          end
        end
      end

      context 'when global config option capacity_mode is not set', config: { capacity_mode: nil } do
        let(:model) do
          new_class do
            table capacity_mode: nil
          end
        end

        it 'creates table with provisioned capacity mode' do
          expect(billing_mode).to eq nil # it means 'PROVISIONED'
        end
      end
    end
  end
end
