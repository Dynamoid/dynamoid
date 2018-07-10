# frozen_string_literal: true

module DumpingHelper
  def raw_attributes(document)
    Dynamoid.adapter.get_item(document.class.table_name, document.id)
  end

  def reload(document)
    document.class.find(document.id)
  end
end
