# encoding: utf-8
module Dynamoid #:nodoc:

  module Adapter
    
    def self.reconnect!
      require "dynamoid/adapter/#{Dynamoid::Config.adapter}"
      extend Dynamoid.const_get(Dynamoid::Config.adapter.capitalize)
    end
    reconnect!
  end
  
end