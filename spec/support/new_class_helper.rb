# frozen_string_literal: true

module NewClassHelper
  def new_class(options = {}, &blk)
    table_name = options[:table_name] || :documents

    klass = Class.new do
      include Dynamoid::Document
      table name: table_name
    end
    klass.class_exec(options, &blk) if block_given?
    klass
  end
end
