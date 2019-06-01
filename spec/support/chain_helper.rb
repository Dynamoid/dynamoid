# frozen_string_literal: true

module ChainHelper
  def put_attributes(table_name, attributes)
    Dynamoid.adapter.put_item(table_name, attributes)
  end
end
