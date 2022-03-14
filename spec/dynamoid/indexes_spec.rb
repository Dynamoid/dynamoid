# frozen_string_literal: true

require 'spec_helper'

describe Dynamoid::Indexes do
  let(:doc_class) do
    new_class
  end

  describe 'base behaviour' do
    it 'has a local secondary indexes hash' do
      expect(doc_class).to respond_to(:local_secondary_indexes)
    end
    it 'has a global secondary indexes hash' do
      expect(doc_class).to respond_to(:global_secondary_indexes)
    end
  end

  describe '.global_secondary_index' do
    context 'with a correct definition' do
      before(:each) do
        @dummy_index = double('Dynamoid::Indexes::Index')
        allow(Dynamoid::Indexes::Index).to receive(:new).and_return(@dummy_index)
      end

      it 'adds the index to the global_secondary_indexes hash' do
        index_key = doc_class.index_key(:some_hash_field)
        doc_class.global_secondary_index(hash_key: :some_hash_field)

        expected_index = doc_class.global_secondary_indexes[index_key]
        expect(expected_index).to eq(@dummy_index)
      end

      it 'with a range key, also adds the index to the global_secondary_indexes hash' do
        index_key = doc_class.index_key(:some_hash_field, :some_range_field)
        doc_class.global_secondary_index(
          hash_key: :some_hash_field,
          range_key: :some_range_field
        )

        expected_index = doc_class.global_secondary_indexes[index_key]
        expect(expected_index).to eq(@dummy_index)
      end

      context 'with optional parameters' do
        context 'with a hash-only index' do
          let(:doc_class_with_gsi) do
            doc_class.global_secondary_index(hash_key: :secondary_hash_field)
          end

          it 'creates the index with the correct options' do
            test_class = doc_class_with_gsi
            index_opts = {
              dynamoid_class: test_class,
              type: :global_secondary,
              read_capacity: Dynamoid::Config.read_capacity,
              write_capacity: Dynamoid::Config.write_capacity,
              hash_key: :secondary_hash_field
            }
            expect(Dynamoid::Indexes::Index).to have_received(:new).with(index_opts)
          end

          it 'adds the index to the global_secondary_indexes hash' do
            test_class = doc_class_with_gsi
            index_key = 'secondary_hash_field'
            expect(test_class.global_secondary_indexes.keys).to eql [index_key]
            expect(test_class.global_secondary_indexes[index_key]).to eq(@dummy_index)
          end
        end

        context 'with a hash and range index' do
          let(:doc_class_with_gsi) do
            doc_class.global_secondary_index(
              hash_key: :secondary_hash_field,
              range_key: :secondary_range_field
            )
          end

          it 'creates the index with the correct options' do
            test_class = doc_class_with_gsi
            index_opts = {
              dynamoid_class: test_class,
              type: :global_secondary,
              read_capacity: Dynamoid::Config.read_capacity,
              write_capacity: Dynamoid::Config.write_capacity,
              hash_key: :secondary_hash_field,
              range_key: :secondary_range_field
            }
            expect(Dynamoid::Indexes::Index).to have_received(:new).with(index_opts)
          end

          it 'adds the index to the global_secondary_indexes hash' do
            test_class = doc_class_with_gsi
            index_key = 'secondary_hash_field_secondary_range_field'
            expect(test_class.global_secondary_indexes[index_key]).to eq(@dummy_index)
          end
        end
      end
    end

    context 'with an improper definition' do
      it 'with a blank definition, throws an error' do
        expect do
          doc_class.global_secondary_index
        end.to raise_error(Dynamoid::Errors::InvalidIndex, /empty index/)
      end
      it 'with no :hash_key, throws an error' do
        expect do
          doc_class.global_secondary_index(range_key: :something)
        end.to raise_error(
          Dynamoid::Errors::InvalidIndex, /hash_key.*specified/
        )
      end
    end
  end

  describe '.local_secondary_index' do
    context 'with correct parameters' do
      before(:each) do
        @dummy_index = double('Dynamoid::Indexes::Index')
        allow(Dynamoid::Indexes::Index).to receive(:new).and_return(@dummy_index)
      end

      let(:doc_class_with_lsi) do
        Class.new do
          include Dynamoid::Document
          table name: :mytable, key: :some_hash_field
          range :some_range_field # @WHAT

          local_secondary_index(range_key: :secondary_range_field)
        end
      end

      it 'creates the index with the correct options' do
        test_class = doc_class_with_lsi
        index_opts = {
          dynamoid_class: test_class,
          type: :local_secondary,
          hash_key: :some_hash_field,
          range_key: :secondary_range_field
        }
        expect(Dynamoid::Indexes::Index).to have_received(:new).with(index_opts)
      end
      it 'adds the index to the local_secondary_indexes hash' do
        test_class = doc_class_with_lsi
        index_key = 'some_hash_field_secondary_range_field'
        expect(test_class.local_secondary_indexes.keys).to eql [index_key]
        expect(test_class.local_secondary_indexes[index_key]).to eq(@dummy_index)
      end
    end

    context 'with an improper definition' do
      let(:doc_class_with_table) do
        Class.new do
          include Dynamoid::Document
          table name: :mytable, key: :some_hash_field
          range :some_range_field
        end
      end

      it 'with a blank definition, throws an error' do
        expect do
          doc_class.local_secondary_index
        end.to raise_error(Dynamoid::Errors::InvalidIndex, /empty/)
      end

      it 'throws an error if the range_key isn`t specified' do
        test_class = doc_class_with_table
        expect do
          test_class.local_secondary_index(projected_attributes: :all)
        end.to raise_error(Dynamoid::Errors::InvalidIndex, /range_key.*specified/)
      end

      it 'throws an error if the range_key is the same as the primary range key' do
        test_class = doc_class_with_table
        expect do
          test_class.local_secondary_index(range_key: :some_range_field)
        end.to raise_error(Dynamoid::Errors::InvalidIndex, /different.*:range_key/)
      end
    end
  end

  describe '.index_key' do
    context 'when hash specified' do
      it 'generates an index key of the form <hash> if only hash is specified' do
        index_key = doc_class.index_key(:some_hash_field)
        expect(index_key).to eq('some_hash_field')
      end
    end

    context 'when hash and range specified' do
      it 'generates an index key of the form <hash>_<range>' do
        index_key = doc_class.index_key(:some_hash_field, :some_range_field)
        expect(index_key).to eq('some_hash_field_some_range_field')
      end

      it 'generates an index key of the form <hash> when range is nil' do
        index_key = doc_class.index_key(:some_hash_field, nil)
        expect(index_key).to eq('some_hash_field')
      end
    end
  end

  describe '.index_name' do
    let(:doc_class) do
      Class.new do
        include Dynamoid::Document
        table name: :mytable
      end
    end

    it 'generates an index name of the form <table_name>_index_<index_key>' do
      expect(doc_class).to receive(:index_key).and_return('whoa_an_index_key')
      index_name = doc_class.index_name(:some_hash_field, :some_range_field)
      expect(index_name).to eq("#{doc_class.table_name}_index_whoa_an_index_key")
    end
  end

  # Index nested class.
  describe 'Index' do
    describe '#initialize' do
      let(:doc_class) do
        Class.new do
          include Dynamoid::Document
          table name: :mytable, key: :some_hash_field

          field :primary_hash_field
          field :primary_range_field
          field :secondary_hash_field
          field :secondary_range_field
          field :array_field, :array
          field :serialized_field, :serialized
        end
      end

      context 'validation' do
        it 'throws an error when :dynamoid_class is not specified' do
          expect do
            Dynamoid::Indexes::Index.new
          end.to raise_error(Dynamoid::Errors::InvalidIndex, /dynamoid_class.*required/)
        end

        it 'throws an error if :type is invalid' do
          expect do
            Dynamoid::Indexes::Index.new(
              dynamoid_class: doc_class,
              hash_key: :primary_hash_field,
              type: :garbage
            )
          end.to raise_error(Dynamoid::Errors::InvalidIndex, /Invalid.*:type/)
        end

        it 'throws an error when :hash_key is not a table attribute' do
          expect do
            Dynamoid::Indexes::Index.new(
              dynamoid_class: doc_class,
              hash_key: :garbage,
              type: :global_secondary
            )
          end.to raise_error(Dynamoid::Errors::InvalidIndex, /No such field/)
        end

        it 'throws an error when :hash_key is of invalid type' do
          expect do
            Dynamoid::Indexes::Index.new(
              dynamoid_class: doc_class,
              hash_key: :array_field,
              type: :global_secondary
            )
          end.to raise_error(Dynamoid::Errors::InvalidIndex, /hash_key.*/)
        end

        it 'throws an error when :range_key is of invalid type' do
          expect do
            Dynamoid::Indexes::Index.new(
              dynamoid_class: doc_class,
              hash_key: :primary_hash_field,
              type: :global_secondary,
              range_key: :array_field
            )
          end.to raise_error(Dynamoid::Errors::InvalidIndex, /range_key.*/)
        end

        it 'throws an error when :range_key is not a table attribute' do
          expect do
            Dynamoid::Indexes::Index.new(
              dynamoid_class: doc_class,
              hash_key: :primary_hash_field,
              type: :global_secondary,
              range_key: :garbage
            )
          end.to raise_error(Dynamoid::Errors::InvalidIndex, /No such field/)
        end

        it 'throws an error if :projected_attributes are invalid' do
          expect do
            Dynamoid::Indexes::Index.new(
              dynamoid_class: doc_class,
              hash_key: :primary_hash_field,
              type: :global_secondary,
              projected_attributes: :garbage
            )
          end.to raise_error(Dynamoid::Errors::InvalidIndex, /Invalid projected attributes/)
        end
      end

      context 'correct parameters' do
        context 'with only required params' do
          let(:defaults_index) do
            Dynamoid::Indexes::Index.new(
              dynamoid_class: doc_class,
              hash_key: :primary_hash_field,
              range_key: :secondary_range_field,
              type: :local_secondary
            )
          end

          it 'sets name to the default index name' do
            expected_name = doc_class.index_name(
              :primary_hash_field,
              :secondary_range_field
            )
            expect(defaults_index.name).to eq(expected_name)
          end

          it 'sets the hash_key_schema' do
            expected = { primary_hash_field: :string }
            expect(defaults_index.hash_key_schema).to eql expected
          end

          it 'sets the range_key_schema' do
            expected = { secondary_range_field: :string }
            expect(defaults_index.range_key_schema).to eql expected
          end

          it 'sets projected attributes to the default :keys_only' do
            expect(defaults_index.projected_attributes).to eq(:keys_only)
          end

          it 'sets all provided attributes' do
            expect(defaults_index.dynamoid_class).to eq(doc_class)
            expect(defaults_index.type).to eq(:local_secondary)
            expect(defaults_index.hash_key).to eq(:primary_hash_field)
            expect(defaults_index.range_key).to eq(:secondary_range_field)
          end
        end

        context 'with other params specified' do
          let(:other_index) do
            Dynamoid::Indexes::Index.new(
              dynamoid_class: doc_class,
              name: :mont_blanc,
              hash_key: :secondary_hash_field,
              type: :global_secondary,
              projected_attributes: %i[secondary_hash_field array_field],
              read_capacity: 100,
              write_capacity: 200
            )
          end
          it 'sets the provided attributes' do
            expect(other_index.dynamoid_class).to eq(doc_class)
            expect(other_index.name).to eq(:mont_blanc)
            expect(other_index.type).to eq(:global_secondary)
            expect(other_index.hash_key).to eq(:secondary_hash_field)
            expect(other_index.range_key.present?).to eq(false)
            expect(other_index.read_capacity).to eq(100)
            expect(other_index.write_capacity).to eq(200)
            expect(other_index.projected_attributes).to eq(
              %i[secondary_hash_field array_field]
            )
          end
        end

        context 'with custom type key params' do
          let(:doc_class) do
            new_class do

              class CustomType
                def dynamoid_dump
                  name
                end

                def self.dynamoid_load(string)
                  new(string.to_s)
                end
              end

              field :custom_type_field, CustomType
              field :custom_type_range_field, CustomType
            end
          end

          let(:index) do
            Dynamoid::Indexes::Index.new(
              dynamoid_class: doc_class,
              hash_key: :custom_type_field,
              range_key: :custom_type_range_field,
              type: :global_secondary
            )
          end

          it 'sets the correct key_schema' do
            expect(index.hash_key_schema).to eql({ custom_type_field: :string })
            expect(index.range_key_schema).to eql({ custom_type_range_field: :string })
          end
        end
      end
    end

    describe '#projection_type' do
      let(:doc_class) do
        Class.new do
          include Dynamoid::Document

          table name: :mytable, key: :primary_hash_field

          field :primary_hash_field
          field :secondary_hash_field
          field :array_field, :array
        end
      end

      it 'projection type is :include' do
        projection_include = Dynamoid::Indexes::Index.new(
          dynamoid_class: doc_class,
          hash_key: :secondary_hash_field,
          type: :global_secondary,
          projected_attributes: %i[secondary_hash_field array_field]
        ).projection_type
        expect(projection_include).to eq(:include)
      end

      it 'projection type is :all' do
        projection_all = Dynamoid::Indexes::Index.new(
          dynamoid_class: doc_class,
          hash_key: :secondary_hash_field,
          type: :global_secondary,
          projected_attributes: :all
        ).projection_type

        expect(projection_all).to eq(:all)
      end
    end
  end
end
