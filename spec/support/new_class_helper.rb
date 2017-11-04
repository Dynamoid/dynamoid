module NewClassHelper
  def new_class(&blk)
    klass = Class.new do
      include Dynamoid::Document
      table name: :documents
    end
    klass.class_eval(&blk) if block_given?
    klass
  end
end
