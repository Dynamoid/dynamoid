# frozen_string_literal: true

module Dynamoid
  module Fields
    # @private
    class Declare
      def initialize(source, name, type, options)
        @source = source
        @name = name.to_sym
        @type = type
        @options = options
      end

      def call
        # Register new field metadata
        @source.attributes = @source.attributes.merge(
          @name => { type: @type }.merge(@options)
        )

        # Should be called before `define_attribute_methods` method because it
        # defines an attribute getter itself
        warn_about_method_overriding

        # Dirty API
        @source.define_attribute_method(@name)

        # Generate getters and setters as well as other helper methods
        generate_instance_methods

        # If alias name specified - generate the same instance methods
        if @options[:alias]
          generate_instance_methods_for_alias
        end
      end

      private

      def warn_about_method_overriding
        warn_if_method_exists(@name)
        warn_if_method_exists("#{@name}=")
        warn_if_method_exists("#{@name}?")
        # TODO: Fix trailing question mark; the generated method is name_before_type_cast without '?'
        warn_if_method_exists("#{@name}_before_type_cast?")
      end

      def generate_instance_methods
        # only local variable is visible in `module_eval` block
        name = @name

        @source.generated_methods.module_eval do
          define_method(name) { read_attribute(name) }
          # TODO: Match ActiveModel / ActiveRecord predicate semantics where 0, '0', and '' evaluate to false
          define_method(:"#{name}?") do
            value = read_attribute(name)
            case value
            when true        then true
            when false, nil  then false
            else
              !value.nil?
            end
          end
          define_method(:"#{name}=") { |value| write_attribute(name, value) }
          define_method(:"#{name}_before_type_cast") { read_attribute_before_type_cast(name) }
        end
      end

      # TODO: Aliases currently only create Ruby method aliases (reader, writer, predicate, and _before_type_cast).
      # There is a gap between the declared field name and its alias:
      # 1. Direct attribute access bypasses method dispatch and does not resolve the alias:
      #    - read_attribute(alias_name) and model[alias_name] return nil (keyed only by primary name).
      #    - write_attribute(alias_name, val) and model[alias_name] = val write to attributes[alias_name]
      #      instead of updating the primary attribute.
      #    - read_attribute_before_type_cast(alias_name) returns nil.
      # 2. Dirty tracking methods are not generated for the alias:
      #    - define_attribute_method is called only for @name, so alias_changed?, alias_was,
      #      alias_change, etc. raise NoMethodError.
      def generate_instance_methods_for_alias
        # only local variable is visible in `module_eval` block
        name = @name

        alias_name = @options[:alias].to_sym

        @source.generated_methods.module_eval do
          alias_method alias_name, name
          alias_method :"#{alias_name}=", :"#{name}="
          alias_method :"#{alias_name}?", :"#{name}?"
          alias_method :"#{alias_name}_before_type_cast", :"#{name}_before_type_cast"
        end
      end

      def warn_if_method_exists(method)
        if @source.method_defined?(method.to_sym)
          Dynamoid.logger.warn("Method #{method} generated for the field #{@name} overrides already existing method")
        end
      end
    end
  end
end
