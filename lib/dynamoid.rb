# frozen_string_literal: true

require 'aws-sdk-dynamodb'
require 'delegate'
require 'time'
require 'securerandom'
require 'active_support'
require 'active_support/core_ext'
require 'active_support/json'
require 'active_support/inflector'
require 'active_support/lazy_load_hooks'
require 'active_support/time_with_zone'
require 'active_model'

require 'dynamoid/version'
require 'dynamoid/errors'
require 'dynamoid/application_time_zone'
require 'dynamoid/dynamodb_time_zone'
require 'dynamoid/fields'
require 'dynamoid/indexes'
require 'dynamoid/associations'
require 'dynamoid/persistence'
require 'dynamoid/dumping'
require 'dynamoid/undumping'
require 'dynamoid/type_casting'
require 'dynamoid/primary_key_type_mapping'
require 'dynamoid/dirty'
require 'dynamoid/validations'
require 'dynamoid/criteria'
require 'dynamoid/finders'
require 'dynamoid/identity_map'
require 'dynamoid/config'
require 'dynamoid/loadable'
require 'dynamoid/components'
require 'dynamoid/document'
require 'dynamoid/adapter'

require 'dynamoid/tasks/database'

require 'dynamoid/middleware/identity_map'

require 'dynamoid/railtie' if defined?(Rails)

module Dynamoid
  extend self

  def configure
    block_given? ? yield(Dynamoid::Config) : Dynamoid::Config
  end
  alias config configure

  def logger
    Dynamoid::Config.logger
  end

  def included_models
    @included_models ||= []
  end

  # @private
  def adapter
    @adapter ||= Adapter.new
  end
end
