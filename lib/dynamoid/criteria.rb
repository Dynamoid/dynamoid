# frozen_string_literal: true

require 'dynamoid/criteria/chain'

module Dynamoid
  # Allows classes to be queried by where, all, first, and each and return criteria chains.
  module Criteria
    extend ActiveSupport::Concern

    module ClassMethods
      %i[where all first last each record_limit scan_limit batch start scan_index_forward find_by_pages project].each do |meth|
        # Return a criteria chain in response to a method that will begin or end a chain. For more information,
        # see Dynamoid::Criteria::Chain.
        #
        # @since 0.2.0
        define_method(meth) do |*args, &blk|
          chain = Dynamoid::Criteria::Chain.new(self)
          if args
            chain.send(meth, *args, &blk)
          else
            chain.send(meth, &blk)
          end
        end
      end
    end
  end
end
