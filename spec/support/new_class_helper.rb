# frozen_string_literal: true

# Declaration DSL of partition key and sort key is weird.
# So let's use helpers to simplify class declaration in specs.
module NewClassHelper
  def new_class(options = {}, &blk)
    table_name = options[:table_name] || :documents
    class_name = (options[:class_name] || table_name).to_s.classify
    partition_key = options[:partition_key]

    klass = Class.new do
      include Dynamoid::Document

      if partition_key
        if partition_key.is_a? Hash
          table name: table_name, key: partition_key[:name]
          if partition_key[:options]
            field partition_key[:name], partition_key[:type] || :string, partition_key[:options]
          else
            field partition_key[:name], partition_key[:type] || :string
          end
        else
          table name: table_name, key: partition_key
          field partition_key
        end
      else
        table name: table_name
      end

      @class_name = class_name

      def self.name
        @class_name
      end
    end
    klass.class_exec(options, &blk) if block_given?
    klass
  end
end
