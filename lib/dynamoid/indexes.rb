# frozen_string_literal: true

module Dynamoid
  module Indexes
    extend ActiveSupport::Concern

    # @private
    # @see https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/HowItWorks.CoreComponents.html#HowItWorks.CoreComponents.PrimaryKey
    # Types allowed in indexes
    PERMITTED_KEY_DYNAMODB_TYPES = %i[
      string
      binary
      number
    ].freeze

    included do
      class_attribute :local_secondary_indexes, instance_accessor: false
      class_attribute :global_secondary_indexes, instance_accessor: false
      self.local_secondary_indexes = {}
      self.global_secondary_indexes = {}
    end

    module ClassMethods
      # Defines a Global Secondary index on a table. Keys can be specified as
      # hash-only, or hash & range.
      #
      #   class Post
      #     include Dynamoid::Document
      #
      #     field :category
      #
      #     global_secondary_index hash_key: :category
      #   end
      #
      # The full example with all the options being specified:
      #
      #   global_secondary_index hash_key: :category,
      #                          range_key: :created_at,
      #                          name: 'posts_category_created_at_index',
      #                          projected_attributes: :all,
      #                          read_capacity: 100,
      #                          write_capacity: 20
      #
      # Global secondary index should be declared after fields for mentioned
      # hash key and optional range key are declared (with method +field+)
      #
      # The only mandatory option is +hash_key+. Raises
      # +Dynamoid::Errors::InvalidIndex+ exception if passed incorrect
      # options.
      #
      # @param [Hash] options the options to pass for this table
      # @option options [Symbol] name the name for the index; this still gets
      #         namespaced. If not specified, will use a default name.
      # @option options [Symbol] hash_key the index hash key column.
      # @option options [Symbol] range_key the index range key column (if
      #         applicable).
      # @option options [Symbol, Array<Symbol>] projected_attributes table
      #         attributes to project for this index. Can be +:keys_only+, +:all+
      #         or an array of included fields. If not specified, defaults to
      #         +:keys_only+.
      # @option options [Integer] read_capacity set the read capacity for the
      #         index; does not work on existing indexes.
      # @option options [Integer] write_capacity set the write capacity for
      #         the index; does not work on existing indexes.
      def global_secondary_index(options = {})
        unless options.present?
          raise Dynamoid::Errors::InvalidIndex, 'empty index definition'
        end

        unless options[:hash_key].present?
          raise Dynamoid::Errors::InvalidIndex, 'A global secondary index requires a :hash_key to be specified'
        end

        index_opts = {
          read_capacity: Dynamoid::Config.read_capacity,
          write_capacity: Dynamoid::Config.write_capacity
        }.merge(options)

        index_opts[:dynamoid_class] = self
        index_opts[:type] = :global_secondary

        index = Dynamoid::Indexes::Index.new(index_opts)
        gsi_key = index_key(options[:hash_key], options[:range_key])
        global_secondary_indexes[gsi_key] = index
        self
      end

      # Defines a local secondary index on a table. Will use the same primary
      # hash key as the table.
      #
      #   class Comment
      #     include Dynamoid::Document
      #
      #     table hash_key: :post_id
      #     range :created_at, :datetime
      #     field :author_id
      #
      #     local_secondary_index range_key: :author_id
      #   end
      #
      # The full example with all the options being specified:
      #
      #   local_secondary_index range_key: :created_at,
      #                         name: 'posts_created_at_index',
      #                         projected_attributes: :all
      #
      # Local secondary index should be declared after fields for mentioned
      # hash key and optional range key are declared (with method +field+) as
      # well as after +table+ method call.
      #
      # The only mandatory option is +range_key+. Raises
      # +Dynamoid::Errors::InvalidIndex+ exception if passed incorrect
      # options.
      #
      # @param [Hash] options options to pass for this index.
      # @option options [Symbol] name the name for the index; this still gets
      #         namespaced. If not specified, a name is automatically generated.
      # @option options [Symbol] range_key the range key column for the index.
      # @option options [Symbol, Array<Symbol>] projected_attributes table
      #         attributes to project for this index. Can be +:keys_only+, +:all+
      #         or an array of included fields. If not specified, defaults to
      #         +:keys_only+.
      def local_secondary_index(options = {})
        unless options.present?
          raise Dynamoid::Errors::InvalidIndex, 'empty index definition'
        end

        primary_hash_key = hash_key
        primary_range_key = range_key
        index_range_key = options[:range_key]

        unless index_range_key.present?
          raise Dynamoid::Errors::InvalidIndex, 'A local secondary index ' \
                                                'requires a :range_key to be specified'
        end

        if primary_range_key.present? && index_range_key == primary_range_key
          raise Dynamoid::Errors::InvalidIndex, 'A local secondary index ' \
                                                'must use a different :range_key than the primary key'
        end

        index_opts = options.merge(
          dynamoid_class: self,
          type: :local_secondary,
          hash_key: primary_hash_key
        )

        index = Dynamoid::Indexes::Index.new(index_opts)
        key = index_key(primary_hash_key, index_range_key)
        local_secondary_indexes[key] = index
        self
      end

      # Returns an index by its hash key and optional range key.
      #
      # It works only for indexes without explicit name declared.
      #
      # @param hash [scalar] the hash key used to declare an index
      # @param range [scalar] the range key used to declare an index (optional)
      # @return [Dynamoid::Indexes::Index, nil] index object or nil if it isn't found
      def find_index(hash, range = nil)
        indexes[index_key(hash, range)]
      end

      # Returns an index by its name
      #
      # @param name [string, symbol] the name of the index to lookup
      # @return [Dynamoid::Indexes::Index, nil] index object or nil if it isn't found
      def find_index_by_name(name)
        string_name = name.to_s
        indexes.each_value.detect { |i| i.name.to_s == string_name }
      end

      # Returns true iff the provided hash[,range] key combo is a local
      # secondary index.
      #
      # @param [Symbol] hash hash key name.
      # @param [Symbol] range range key name.
      # @return [Boolean] true iff provided keys correspond to a local
      #         secondary index.
      def is_local_secondary_index?(hash, range = nil)
        local_secondary_indexes[index_key(hash, range)].present?
      end

      # Returns true iff the provided hash[,range] key combo is a global
      # secondary index.
      #
      # @param [Symbol] hash hash key name.
      # @param [Symbol] range range key name.
      # @return [Boolean] true iff provided keys correspond to a global
      #         secondary index.
      def is_global_secondary_index?(hash, range = nil)
        global_secondary_indexes[index_key(hash, range)].present?
      end

      # Generates a convenient lookup key name for a hash/range index.
      # Should normally not be used directly.
      #
      # @param [Symbol] hash hash key name.
      # @param [Symbol] range range key name.
      # @return [String] returns "hash" if hash only, "hash_range" otherwise.
      def index_key(hash, range = nil)
        name = hash.to_s
        name += "_#{range}" if range.present?
        name
      end

      # Generates a default index name.
      #
      # @param [Symbol] hash hash key name.
      # @param [Symbol] range range key name.
      # @return [String] index name of the form "table_name_index_index_key".
      def index_name(hash, range = nil)
        "#{table_name}_index_#{index_key(hash, range)}"
      end

      # Convenience method to return all indexes on the table.
      #
      # @return [Hash<String, Object>] the combined hash of global and local
      #         secondary indexes.
      def indexes
        local_secondary_indexes.merge(global_secondary_indexes)
      end

      # Returns an array of hash keys for all the declared Glocal Secondary
      # Indexes.
      #
      # @return [Array[String]] array of hash keys
      def indexed_hash_keys
        global_secondary_indexes.map do |_name, index|
          index.hash_key.to_s
        end
      end
    end

    # Represents the attributes of a DynamoDB index.
    class Index
      include ActiveModel::Validations

      PROJECTION_TYPES = %i[keys_only all].to_set
      DEFAULT_PROJECTION_TYPE = :keys_only

      attr_accessor :name, :dynamoid_class, :type, :hash_key, :range_key,
                    :hash_key_schema, :range_key_schema, :projected_attributes,
                    :read_capacity, :write_capacity

      validate do
        validate_index_type
        validate_hash_key
        validate_range_key
        validate_projected_attributes
      end

      def initialize(attrs = {})
        unless attrs[:dynamoid_class].present?
          raise Dynamoid::Errors::InvalidIndex, ':dynamoid_class is required'
        end

        @dynamoid_class = attrs[:dynamoid_class]
        @type = attrs[:type]
        @hash_key = attrs[:hash_key]
        @range_key = attrs[:range_key]
        @name = attrs[:name] || @dynamoid_class.index_name(@hash_key, @range_key)
        @projected_attributes =
          attrs[:projected_attributes] || DEFAULT_PROJECTION_TYPE
        @read_capacity = attrs[:read_capacity]
        @write_capacity = attrs[:write_capacity]

        raise Dynamoid::Errors::InvalidIndex, self unless valid?
      end

      # Convenience method to determine the projection type for an index.
      # Projection types are: :keys_only, :all, :include.
      #
      # @return [Symbol] the projection type.
      def projection_type
        if @projected_attributes.is_a? Array
          :include
        else
          @projected_attributes
        end
      end

      private

      def validate_projected_attributes
        unless @projected_attributes.is_a?(Array) ||
               PROJECTION_TYPES.include?(@projected_attributes)
          errors.add(:projected_attributes, 'Invalid projected attributes specified.')
        end
      end

      def validate_index_type
        unless @type.present? &&
               %i[local_secondary global_secondary].include?(@type)
          errors.add(:type, 'Invalid index :type specified')
        end
      end

      def validate_hash_key
        validate_index_key(:hash_key, @hash_key)
      end

      def validate_range_key
        validate_index_key(:range_key, @range_key)
      end

      def validate_index_key(key_param, key_val)
        return if key_val.blank?

        key_field_attributes = @dynamoid_class.attributes[key_val]
        if key_field_attributes.blank?
          errors.add(key_param, "No such field #{key_val} defined on table")
          return
        end

        key_dynamodb_type = dynamodb_type(key_field_attributes[:type], key_field_attributes)
        if PERMITTED_KEY_DYNAMODB_TYPES.include?(key_dynamodb_type)
          send(:"#{key_param}_schema=", { key_val => key_dynamodb_type })
        else
          errors.add(key_param, "Index :#{key_param} is not a valid key type")
        end
      end

      def dynamodb_type(field_type, options)
        PrimaryKeyTypeMapping.dynamodb_type(field_type, options)
      rescue Errors::UnsupportedKeyType
        field_type
      end
    end
  end
end
