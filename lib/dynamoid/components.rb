# frozen_string_literal: true

module Dynamoid
  # All modules that a Document is composed of are defined in this
  # module, to keep the document class from getting too cluttered.
  # @private
  module Components
    extend ActiveSupport::Concern

    included do
      extend ActiveModel::Translation
      extend ActiveModel::Callbacks

      define_model_callbacks :create, :save, :destroy, :initialize, :update

      before_create :set_created_at
      before_save :set_updated_at
      before_save :set_expires_field
      after_initialize :set_inheritance_field
    end

    include ActiveModel::AttributeMethods # Actually it will be inclided in Dirty module again
    include ActiveModel::Conversion
    include ActiveModel::MassAssignmentSecurity if defined?(ActiveModel::MassAssignmentSecurity)
    include ActiveModel::Naming
    include ActiveModel::Observing if defined?(ActiveModel::Observing)
    include ActiveModel::Serializers::JSON
    include ActiveModel::Serializers::Xml if defined?(ActiveModel::Serializers::Xml)
    include Dynamoid::Persistence
    include Dynamoid::Loadable
    # Dirty module should be included after Persistence and Loadable
    # because it overrides some methods declared in these modules
    include Dynamoid::Dirty
    include Dynamoid::Fields
    include Dynamoid::Indexes
    include Dynamoid::Finders
    include Dynamoid::Associations
    include Dynamoid::Criteria
    include Dynamoid::Validations
    include Dynamoid::IdentityMap
  end
end
