# encoding: utf-8
require "uri"
require "dynamoid/config/options"

module Dynamoid #:nodoc
  
  module Config
    extend self
    extend Options
    include ActiveModel::Observing

    option :adapter, :default => 'local'
    option :namespace, :default => 'dynamoid'

  end
end