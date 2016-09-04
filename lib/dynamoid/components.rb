# encoding: utf-8
module Dynamoid

  # All modules that a Document is composed of are defined in this
  # module, to keep the document class from getting too cluttered.
  module Components
    extend ActiveSupport::Concern

    included do
      extend ActiveModel::Translation
      extend ActiveModel::Callbacks

      define_model_callbacks :create, :save, :destroy, :initialize, :update

      before_create :set_created_at
      before_save :set_updated_at
      after_initialize :set_type
    end

    include ActiveModel::AttributeMethods
    include ActiveModel::Conversion
    include ActiveModel::MassAssignmentSecurity if defined?(ActiveModel::MassAssignmentSecurity)
    include ActiveModel::Naming
    include ActiveModel::Observing if defined?(ActiveModel::Observing)
    include ActiveModel::Serializers::JSON
    include Dynamoid::Fields
    include Dynamoid::Indexes
    include Dynamoid::Persistence
    include Dynamoid::Finders
    include Dynamoid::Associations
    include Dynamoid::Criteria
    include Dynamoid::Validations
    include Dynamoid::IdentityMap
    include Dynamoid::Dirty
  end
end
