require "delegate"
require "time"
require "securerandom"
require "active_support/core_ext"
require 'active_support/json'
require "active_support/inflector"
require "active_support/lazy_load_hooks"
require "active_support/time_with_zone"
require "active_model"

require 'dynamoid/errors'
require 'dynamoid/fields'
require 'dynamoid/indexes'
require 'dynamoid/associations'
require 'dynamoid/persistence'
require 'dynamoid/validations'
require 'dynamoid/criteria'
require 'dynamoid/finders'
require 'dynamoid/config'
require 'dynamoid/components'
require 'dynamoid/document'
require 'dynamoid/adapter'

module Dynamoid
  extend self

  MAX_ITEM_SIZE = 65_536
  
  def configure
    block_given? ? yield(Dynamoid::Config) : Dynamoid::Config
    Dynamoid::Adapter.reconnect!
  end
  alias :config :configure
  
  def logger
    Dynamoid::Config.logger
  end
  
  def included_models
    @included_models ||= []
  end
  
end
