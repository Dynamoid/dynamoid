# frozen_string_literal: true

module PersistenceHelper
  def new_class_with_partion_key(name:, type:, **opts)
    Class.new do
      include Dynamoid::Document
      table name: :documents, key: name

      field name, type, opts
    end
  end

  def new_class_with_sort_key(name:, type:, **opts)
    Class.new do
      include Dynamoid::Document
      table name: :documents

      range name, type, opts
    end
  end

  def raw_attribute_types(table_name)
    Dynamoid.adapter.adapter.send(:describe_table, table_name).schema.attribute_definitions.map do |ad|
      [ad.attribute_name, ad.attribute_type]
    end.to_h
  end
end
