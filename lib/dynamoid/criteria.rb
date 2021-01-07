# frozen_string_literal: true

require 'dynamoid/criteria/chain'

module Dynamoid
  # Allows classes to be queried by where, all, first, and each and return criteria chains.
  module Criteria
    extend ActiveSupport::Concern

    # @private
    module ClassMethods
      %i[where consistent all first last delete_all destroy_all each record_limit scan_limit batch start scan_index_forward find_by_pages project pluck].each do |meth|
        # Return a criteria chain in response to a method that will begin or end a chain. For more information,
        # see Dynamoid::Criteria::Chain.
        #
        # @since 0.2.0
        define_method(meth) do |*args, &blk|
          # Don't use keywork arguments delegating (with **kw). It works in
          # different way in different Ruby versions: <= 2.6, 2.7, 3.0 and in some
          # future 3.x versions. Providing that there are no downstream methods
          # with keyword arguments in Chain.
          #
          # https://eregon.me/blog/2019/11/10/the-delegation-challenge-of-ruby27.html

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
