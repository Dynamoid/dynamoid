# encoding: utf-8
require 'dynamoid/criteria/chain'

module Dynamoid

  # Allows classes to be queried by where, all, first, and each and return criteria chains.
  module Criteria
    extend ActiveSupport::Concern
    
    module ClassMethods
      
      [:where, :all, :first, :each, :limit, :start].each do |meth|
        # Return a criteria chain in response to a method that will begin or end a chain. For more information, 
        # see Dynamoid::Criteria::Chain.
        #
        # @since 0.2.0
        define_method(meth) do |*args|
          chain = Dynamoid::Criteria::Chain.new(self)
          if args
            chain.send(meth, *args)
          else
            chain.send(meth)
          end
        end
      end
    end
  end
  
end
