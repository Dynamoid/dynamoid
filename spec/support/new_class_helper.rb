# frozen_string_literal: true

module NewClassHelper
  def new_class(options = {}, &blk)
    table_name = options[:table_name] || :documents
    class_name = (options[:class_name] || table_name).to_s.classify

    klass = Class.new do
      include Dynamoid::Document
      table name: table_name

      @class_name = class_name

      def self.name
        @class_name
      end
    end
    klass.class_exec(options, &blk) if block_given?
    klass
  end
end
