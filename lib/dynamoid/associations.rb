# encoding: utf-8
require 'dynamoid/associations/association'
require 'dynamoid/associations/single_association'
require 'dynamoid/associations/many_association'
require 'dynamoid/associations/has_many'
require 'dynamoid/associations/belongs_to'
require 'dynamoid/associations/has_one'
require 'dynamoid/associations/has_and_belongs_to_many'

module Dynamoid

  # Connects models together through the magic of associations. We enjoy four different kinds of associations presently:
  #   * belongs_to
  #   * has_and_belongs_to_many
  #   * has_many
  #   * has_one
  module Associations
    extend ActiveSupport::Concern
    
    # Create the association tracking attribute and initialize it to an empty hash.
    included do
      class_attribute :associations
      
      self.associations = {}
    end

    module ClassMethods
      
      # create a has_many association for this document.
      #
      # @param [Symbol] name the name of the association
      # @param [Hash] options options to pass to the association constructor
      # @option options [Class] :class the target class of the has_many association; that is, the belongs_to class
      # @option options [Symbol] :class_name the name of the target class of the association; that is, the name of the belongs_to class
      # @option options [Symbol] :inverse_of the name of the association on the target class; that is, if the class has a belongs_to association, the name of that association
      #
      # @since 0.2.0
      def has_many(name, options = {})
        association(:has_many, name, options)
      end
      
      # create a has_one association for this document.
      #
      # @param [Symbol] name the name of the association
      # @param [Hash] options options to pass to the association constructor
      # @option options [Class] :class the target class of the has_one association; that is, the belongs_to class
      # @option options [Symbol] :class_name the name of the target class of the association; that is, the name of the belongs_to class
      # @option options [Symbol] :inverse_of the name of the association on the target class; that is, if the class has a belongs_to association, the name of that association
      #
      # @since 0.2.0
      def has_one(name, options = {})
        association(:has_one, name, options)
      end
      
      # create a belongs_to association for this document.
      #
      # @param [Symbol] name the name of the association
      # @param [Hash] options options to pass to the association constructor
      # @option options [Class] :class the target class of the has_one association; that is, the has_many or has_one class
      # @option options [Symbol] :class_name the name of the target class of the association; that is, the name of the has_many or has_one class
      # @option options [Symbol] :inverse_of the name of the association on the target class; that is, if the class has a has_many or has_one association, the name of that association
      #
      # @since 0.2.0
      def belongs_to(name, options = {})
        association(:belongs_to, name, options)
      end
      
      # create a has_and_belongs_to_many association for this document.
      #
      # @param [Symbol] name the name of the association
      # @param [Hash] options options to pass to the association constructor
      # @option options [Class] :class the target class of the has_and_belongs_to_many association; that is, the belongs_to class
      # @option options [Symbol] :class_name the name of the target class of the association; that is, the name of the belongs_to class
      # @option options [Symbol] :inverse_of the name of the association on the target class; that is, if the class has a belongs_to association, the name of that association
      #
      # @since 0.2.0
      def has_and_belongs_to_many(name, options = {})
        association(:has_and_belongs_to_many, name, options)
      end
      
      private

      # create getters and setters for an association.
      #
      # @param [Symbol] symbol the type (:has_one, :has_many, :has_and_belongs_to_many, :belongs_to) of the association
      # @param [Symbol] name the name of the association
      # @param [Hash] options options to pass to the association constructor; see above for all valid options
      #
      # @since 0.2.0      
      def association(type, name, options = {})
        field "#{name}_ids".to_sym, :set
        self.associations[name] = options.merge(:type => type)
        define_method(name) do
          @associations ||= {}
          @associations[name] ||= Dynamoid::Associations.const_get(type.to_s.camelcase).new(self, name, options)
        end
        define_method("#{name}=".to_sym) do |objects|
          @associations ||= {}
          @associations[name] ||= Dynamoid::Associations.const_get(type.to_s.camelcase).new(self, name, options)
          @associations[name].setter(objects)
        end
      end
    end
    
  end
  
end
