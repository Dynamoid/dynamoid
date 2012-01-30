# encoding: utf-8
module Dynamoid #:nodoc
  module Components #:nodoc
    extend ActiveSupport::Concern

    # All modules that a +Document+ is composed of are defined in this
    # module, to keep the document class from getting too cluttered.
    included do
      extend ActiveModel::Translation
    end

    include ActiveModel::Conversion
    include ActiveModel::MassAssignmentSecurity
    include ActiveModel::Naming
    include ActiveModel::Observing
    include ActiveModel::Serializers::JSON
    include ActiveModel::Serializers::Xml
    include Dynamoid::Attributes
    include Dynamoid::Fields
    include Dynamoid::Persistence
  end
end
