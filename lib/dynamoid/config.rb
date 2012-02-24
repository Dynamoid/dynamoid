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
    option :access_key
    option :secret_key
    option :warn_on_scan, :default => true

  end
end