# frozen_string_literal: true

module PersistenceHelper
  def raw_attribute_types(table_name)
    Dynamoid.adapter.adapter.send(:describe_table, table_name).schema.attribute_definitions.map do |ad|
      [ad.attribute_name, ad.attribute_type]
    end.to_h
  end

  def tables_created
    Dynamoid.adapter.list_tables
  end
end
