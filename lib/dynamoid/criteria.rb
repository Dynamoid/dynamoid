# encoding: utf-8
require 'dynamoid/criteria/chain'

module Dynamoid #:nodoc:

  # This module defines criteria and criteria chains.
  module Criteria
    extend ActiveSupport::Concern
    
    module ClassMethods
      [:where, :all, :first, :each].each do |meth|
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