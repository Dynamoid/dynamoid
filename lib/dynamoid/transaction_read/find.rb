# frozen_string_literal: true

module Dynamoid
  class TransactionRead
    class Find
      attr_reader :model_class

      def initialize(model_class, *ids, **options)
        @model_class = model_class
        @ids = ids
        @options = options
      end

      def on_registration
        validate_primary_key!
      end

      def observable_by_user_result
        nil
      end

      def action_request
        if single_key_given?
          action_request_for_single_key
        else
          action_request_for_multiple_keys
        end
      end

      def process_responses(responses)
        models = responses.map do |response|
          if response.item
            @model_class.from_database(response.item)
          elsif @options[:raise_error] == false
            nil
          else
            message = build_record_not_found_exception_message(responses)
            raise Dynamoid::Errors::RecordNotFound, message
          end
        end

        unless single_key_given?
          models.compact!
        end

        models.each { |m| m&.run_callbacks :find }
        models
      end

      private

      def single_key_given?
        @ids.size == 1 && !@ids[0].is_a?(Array)
      end

      def validate_primary_key!
        if single_key_given?
          partition_key = @ids[0]
          sort_key = @options[:range_key]

          raise Dynamoid::Errors::MissingHashKey if partition_key.nil?
          raise Dynamoid::Errors::MissingRangeKey if @model_class.range_key && sort_key.nil?
        else
          ids = @ids.flatten(1)

          raise Dynamoid::Errors::MissingHashKey if ids.any? { |pk, _sk| pk.nil? }
          raise Errors::MissingRangeKey if @model_class.range_key && ids.any? { |_pk, sk| sk.nil? }
        end
      end

      def action_request_for_single_key
        partition_key = @ids[0]

        key = { @model_class.hash_key => cast_and_dump_attribute(@model_class.hash_key, partition_key) }

        if @model_class.range_key
          sort_key = @options[:range_key]
          key[@model_class.range_key] = cast_and_dump_attribute(@model_class.range_key, sort_key)
        end

        {
          get: {
            key: key,
            table_name: @model_class.table_name
          }
        }
      end

      def action_request_for_multiple_keys
        @ids.flatten(1).map do |id|
          if @model_class.range_key
            # expect [hash-key, range-key] pair
            pk, sk = id
            pk_dumped = cast_and_dump_attribute(@model_class.hash_key, pk)
            sk_dumped = cast_and_dump_attribute(@model_class.range_key, sk)

            key = { @model_class.hash_key => pk_dumped, @model_class.range_key => sk_dumped }
          else
            pk_dumped = cast_and_dump_attribute(@model_class.hash_key, id)

            key = { @model_class.hash_key => pk_dumped }
          end

          {
            get: {
              key: key,
              table_name: @model_class.table_name
            }
          }
        end
      end

      def cast_and_dump_attribute(name, value)
        attribute_options = @model_class.attributes[name]
        casted_value = TypeCasting.cast_field(value, attribute_options)
        Dumping.dump_field(casted_value, attribute_options)
      end

      def build_record_not_found_exception_message(responses)
        items = responses.map(&:item)
        ids = @ids.flatten(1)

        if single_key_given?
          id = ids[0]
          primary_key = @model_class.range_key ? "(#{id.inspect},#{@options[:range_key].inspect})" : id.inspect
          message = "Couldn't find #{@model_class.name} with primary key #{primary_key}"
        else
          ids_list = @model_class.range_key ? ids.map { |pk, sk| "(#{pk.inspect},#{sk.inspect})" } : ids.map(&:inspect)
          message = "Couldn't find all #{@model_class.name.pluralize} with primary keys [#{ids_list.join(', ')}] "
          message += "(found #{items.compact.size} results, but was looking for #{items.size})"
        end

        message
      end
    end
  end
end
