# frozen_string_literal: true

require_relative 'until_past_table_status'

module Dynamoid
  module AdapterPlugin
    class AwsSdkV3
      class CreateTable
        attr_reader :client, :table_name, :key, :options

        def initialize(client, table_name, key, options)
          @client = client
          @table_name = table_name
          @key = key
          @options = options
        end

        def call
          read_capacity = options[:read_capacity] || Dynamoid::Config.read_capacity
          write_capacity = options[:write_capacity] || Dynamoid::Config.write_capacity

          secondary_indexes = options.slice(
            :local_secondary_indexes,
            :global_secondary_indexes
          )
          ls_indexes = options[:local_secondary_indexes]
          gs_indexes = options[:global_secondary_indexes]

          key_schema = {
            hash_key_schema: { key => (options[:hash_key_type] || :string) },
            range_key_schema: options[:range_key]
          }
          attribute_definitions = build_all_attribute_definitions(
            key_schema,
            secondary_indexes
          )
          key_schema = aws_key_schema(
            key_schema[:hash_key_schema],
            key_schema[:range_key_schema]
          )

          client_opts = {
            table_name: table_name,
            provisioned_throughput: {
              read_capacity_units: read_capacity,
              write_capacity_units: write_capacity
            },
            key_schema: key_schema,
            attribute_definitions: attribute_definitions
          }

          if ls_indexes.present?
            client_opts[:local_secondary_indexes] = ls_indexes.map do |index|
              index_to_aws_hash(index)
            end
          end

          if gs_indexes.present?
            client_opts[:global_secondary_indexes] = gs_indexes.map do |index|
              index_to_aws_hash(index)
            end
          end
          resp = client.create_table(client_opts)
          options[:sync] = true if !options.key?(:sync) && ls_indexes.present? || gs_indexes.present?
          UntilPastTableStatus.new(client, table_name, :creating).call if options[:sync] &&
                                                                  (status = PARSE_TABLE_STATUS.call(resp, :table_description)) &&
                                                                  status == TABLE_STATUSES[:creating]
          # Response to original create_table, which, if options[:sync]
          #   may have an outdated table_description.table_status of "CREATING"
          resp
        end

        private

        # Builds aws attributes definitions based off of primary hash/range and
        # secondary indexes
        #
        # @param key_data
        # @option key_data [Hash] hash_key_schema - eg: {:id => :string}
        # @option key_data [Hash] range_key_schema - eg: {:created_at => :number}
        # @param [Hash] secondary_indexes
        # @option secondary_indexes [Array<Dynamoid::Indexes::Index>] :local_secondary_indexes
        # @option secondary_indexes [Array<Dynamoid::Indexes::Index>] :global_secondary_indexes
        def build_all_attribute_definitions(key_schema, secondary_indexes = {})
          ls_indexes = secondary_indexes[:local_secondary_indexes]
          gs_indexes = secondary_indexes[:global_secondary_indexes]

          attribute_definitions = []

          attribute_definitions << build_attribute_definitions(
            key_schema[:hash_key_schema],
            key_schema[:range_key_schema]
          )

          if ls_indexes.present?
            ls_indexes.map do |index|
              attribute_definitions << build_attribute_definitions(
                index.hash_key_schema,
                index.range_key_schema
              )
            end
          end

          if gs_indexes.present?
            gs_indexes.map do |index|
              attribute_definitions << build_attribute_definitions(
                index.hash_key_schema,
                index.range_key_schema
              )
            end
          end

          attribute_definitions.flatten!
          # uniq these definitions because range keys might be common between
          # primary and secondary indexes
          attribute_definitions.uniq!
          attribute_definitions
        end

        # Builds an attribute definitions based on hash key and range key
        # @params [Hash] hash_key_schema - eg: {:id => :string}
        # @params [Hash] range_key_schema - eg: {:created_at => :datetime}
        # @return [Array]
        def build_attribute_definitions(hash_key_schema, range_key_schema = nil)
          attrs = []

          attrs << attribute_definition_element(
            hash_key_schema.keys.first,
            hash_key_schema.values.first
          )

          if range_key_schema.present?
            attrs << attribute_definition_element(
              range_key_schema.keys.first,
              range_key_schema.values.first
            )
          end

          attrs
        end

        # Builds an aws attribute definition based on name and dynamoid type
        # @params [Symbol] name - eg: :id
        # @params [Symbol] dynamoid_type - eg: :string
        # @return [Hash]
        def attribute_definition_element(name, dynamoid_type)
          aws_type = api_type(dynamoid_type)

          {
            attribute_name: name.to_s,
            attribute_type: aws_type
          }
        end

        # Converts from symbol to the API string for the given data type
        # E.g. :number -> 'N'
        def api_type(type)
          case type
          when :string then STRING_TYPE
          when :number then NUM_TYPE
          when :binary then BINARY_TYPE
          else raise "Unknown type: #{type}"
          end
        end

        # Converts a Dynamoid::Indexes::Index to an AWS API-compatible hash.
        # This resulting hash is of the form:
        #
        #   {
        #     index_name: String
        #     keys: {
        #       hash_key: aws_key_schema (hash)
        #       range_key: aws_key_schema (hash)
        #     }
        #     projection: {
        #       projection_type: (ALL, KEYS_ONLY, INCLUDE) String
        #       non_key_attributes: (optional) Array
        #     }
        #     provisioned_throughput: {
        #       read_capacity_units: Integer
        #       write_capacity_units: Integer
        #     }
        #   }
        #
        # @param [Dynamoid::Indexes::Index] index the index.
        # @return [Hash] hash representing an AWS Index definition.
        def index_to_aws_hash(index)
          key_schema = aws_key_schema(index.hash_key_schema, index.range_key_schema)

          hash = {
            index_name: index.name,
            key_schema: key_schema,
            projection: {
              projection_type: index.projection_type.to_s.upcase
            }
          }

          # If the projection type is include, specify the non key attributes
          if index.projection_type == :include
            hash[:projection][:non_key_attributes] = index.projected_attributes
          end

          # Only global secondary indexes have a separate throughput.
          if index.type == :global_secondary
            hash[:provisioned_throughput] = {
              read_capacity_units: index.read_capacity,
              write_capacity_units: index.write_capacity
            }
          end
          hash
        end

        # Converts hash_key_schema and range_key_schema to aws_key_schema
        # @param [Hash] hash_key_schema eg: {:id => :string}
        # @param [Hash] range_key_schema eg: {:created_at => :number}
        # @return [Array]
        def aws_key_schema(hash_key_schema, range_key_schema)
          schema = [{
            attribute_name: hash_key_schema.keys.first.to_s,
            key_type: HASH_KEY
          }]

          if range_key_schema.present?
            schema << {
              attribute_name: range_key_schema.keys.first.to_s,
              key_type: RANGE_KEY
            }
          end
          schema
        end
      end
    end
  end
end
