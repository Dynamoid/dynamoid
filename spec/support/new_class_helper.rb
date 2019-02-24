# frozen_string_literal: true

# Declaration DSL of partition key and sort key is weird.
# So let's use helpers to simplify class declaration in specs.
module NewClassHelper
  def new_class(options = {}, &blk)
    table_name = options[:table_name] || :documents
    class_name = (options[:class_name] || table_name).to_s.classify
    partition_key = options[:partition_key]
    sort_key = options[:sort_key]

    klass = Class.new do
      include Dynamoid::Document

      if partition_key
        table name: table_name, key: partition_key
        field partition_key
      else
        table name: table_name
      end

      if sort_key
        unless sort_key.is_a?(Hash)
          sort_key = { name: sort_key, type: :string }
        end
        range sort_key[:name], sort_key[:type]
      end

      @class_name = class_name

      def self.name
        @class_name
      end
    end
    klass.class_exec(options, &blk) if block_given?
    klass
  end

  def new_class_with_partition_key(name, type: :string, **opts, &blk)
    klass = Class.new do
      include Dynamoid::Document
      table name: :documents, key: name

      field name, type, opts
    end

    klass.class_exec(&blk) if block_given?
    klass
  end

  def new_class_with_sort_key(name, type:, **opts, &blk)
    klass = Class.new do
      include Dynamoid::Document
      table name: :documents

      range name, type, opts
    end

    klass.class_exec(&blk) if block_given?
    klass
  end
end
