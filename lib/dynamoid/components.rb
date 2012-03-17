# encoding: utf-8
module Dynamoid #:nodoc
  module Components #:nodoc
    extend ActiveSupport::Concern

    # All modules that a +Document+ is composed of are defined in this
    # module, to keep the document class from getting too cluttered.
    included do
      extend ActiveModel::Translation
      extend ActiveModel::Callbacks

      define_model_callbacks :create, :save, :destroy
      
      before_create :set_created_at
      before_save :set_updated_at
    end

    include ActiveModel::Conversion
    include ActiveModel::MassAssignmentSecurity
    include ActiveModel::Naming
    include ActiveModel::Observing
    include ActiveModel::Serializers::JSON
    include ActiveModel::Serializers::Xml
    include Dynamoid::Fields
    include Dynamoid::Indexes
    include Dynamoid::Persistence
    include Dynamoid::Finders
    include Dynamoid::Associations
    include Dynamoid::Criteria
    include Dynamoid::Validations
  end
end
