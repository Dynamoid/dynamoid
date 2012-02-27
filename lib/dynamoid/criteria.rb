require 'dynamoid/criteria/chain'

# encoding: utf-8
module Dynamoid #:nodoc:

  # This module defines criteria and criteria chains.
  module Criteria
    extend ActiveSupport::Concern
    
    module ClassMethods
      [:where, :all, :first, :each].each do |meth|
        define_method(meth) do |opts|
          chain = Dynamoid::Criteria::Chain.new(self)
          chain.send(meth, opts)
        end
      end
    end
  end
  
end