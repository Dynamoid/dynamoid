# encoding: utf-8
module Dynamoid #:nodoc:

  module Associations
    module ManyAssociation

      # Is this array equal to the association's records?
      #
      # @return [Boolean] true/false
      #
      # @since 0.2.0
      def ==(other)
        records == Array(other)
      end

      # Delegate methods we don't find directly to the records array.
      #
      # @since 0.2.0
      def method_missing(method, *args)
        if records.respond_to?(method)
          records.send(method, *args)
        else
          super
        end
      end
    end
  end
end
