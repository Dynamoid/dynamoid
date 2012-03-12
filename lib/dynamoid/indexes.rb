# encoding: utf-8
module Dynamoid #:nodoc:

  # Builds all indexes present on the model.
  module Indexes
    extend ActiveSupport::Concern

    included do
      class_attribute :indexes
      
      self.indexes = {}
    end
    
    module ClassMethods
      def index(name, options = {})
        options[:range_key] ||= nil
        name = Array(name).collect(&:to_s).sort.collect(&:to_sym)
        options[:hash_key] ||= name
        raise Dynamoid::Errors::InvalidField, 'A key specified for an index is not a field' unless name.all?{|n| self.attributes.include?(n)}
        self.indexes[name] = options
        create_indexes
      end
      
      def create_indexes
        self.indexes.each do |index, options|
          self.create_table(index_table_name(options[:hash_key]), :id) unless self.table_exists?(index_table_name(options[:hash_key]))
        end
      end
      
      def index_table_name(index)
        "#{Dynamoid::Config.namespace}_index_#{self.to_s.downcase}_#{index.collect(&:to_s).collect(&:pluralize).join('_and_')}"
      end
      
      def key_for_index(index, values = [])
        values = values.collect(&:to_s).sort.join('.')
      end
    end
    
    def key_for_index(index)
      self.class.key_for_index(index, index.collect{|i| self.send(i)})
    end
    
    def save_indexes
      self.class.indexes.each do |index, options|
        next if self.key_for_index(options[:hash_key]).blank?
        existing = Dynamoid::Adapter.read(self.class.index_table_name(options[:hash_key]), self.key_for_index(options[:hash_key]))
        ids = existing ? existing[:ids] : Set.new
        Dynamoid::Adapter.write(self.class.index_table_name(options[:hash_key]), {:id => self.key_for_index(options[:hash_key]), :ids => ids.merge([self.id])})
      end
    end
    
    def delete_indexes
      self.class.indexes.each do |index, options|
        next if self.key_for_index(options[:hash_key]).blank?
        existing = Dynamoid::Adapter.read(self.class.index_table_name(options[:hash_key]), self.key_for_index(options[:hash_key]))
        next unless existing && existing[:ids]
        Dynamoid::Adapter.write(self.class.index_table_name(options[:hash_key]), {:id => self.key_for_index(options[:hash_key]), :ids => existing[:ids] - [self.id]})
      end
    end
  end
  
end