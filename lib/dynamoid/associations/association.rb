# encoding: utf-8
module Dynamoid #:nodoc:

  # The base association module which all associations include. Every association has two very important components: the source and
  # the target. The source is the object which is calling the association information. It always has the target_ids inside of an attribute on itself.
  # The target is the object which is referencing by this association.
  module Associations
    module Association
      attr_accessor :name, :options, :source

      # Create a new association.
      #
      # @param [Class] source the source record of the association; that is, the record that you already have
      # @param [Symbol] name the name of the association
      # @param [Hash] options optional parameters for the association
      # @option options [Class] :class the target class of the association; that is, the class to which the association objects belong
      # @option options [Symbol] :class_name the name of the target class of the association; only this or Class is necessary
      # @option options [Symbol] :inverse_of the name of the association on the target class
      #
      # @return [Dynamoid::Association] the actual association instance itself
      #
      # @since 0.2.0
      def initialize(source, name, options)
        @name = name
        @options = options
        @source = source
      end

      private

      # The target class name, either inferred through the association's name or specified in options.
      #
      # @since 0.2.0
      def target_class_name
        options[:class_name] || name.to_s.classify
      end

      # The target class, either inferred through the association's name or specified in options.
      #
      # @since 0.2.0
      def target_class
        options[:class] || target_class_name.constantize
      end

      # The target attribute: that is, the attribute on each object of the association that should reference the source.
      #
      # @since 0.2.0
      def target_attribute
        "#{target_association}_ids".to_sym if target_association
      end

      # The ids in the target association.
      #
      # @since 0.2.0
      def target_ids
        target.send(target_attribute) || Set.new
      end

      # The ids in the target association.
      #
      # @since 0.2.0
      def source_class
        source.class
      end

      # The source's association attribute: the name of the association with _ids afterwards, like "users_ids".
      #
      # @since 0.2.0
      def source_attribute
        "#{name}_ids".to_sym
      end

      # The ids in the source association.
      #
      # @since 0.2.0
      def source_ids
        source.send(source_attribute) || Set.new
      end

    end
  end

end
