# frozen_string_literal: true

module NewClassHelper
  def new_class(table_name: nil, &blk)
    klass = Class.new do
      include Dynamoid::Document
      table name: (table_name || :documents)
    end
    klass.class_eval(&blk) if block_given?
    klass
  end
end
