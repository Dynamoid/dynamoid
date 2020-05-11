# frozen_string_literal: true

require 'dynamoid/associations/association'
require 'dynamoid/associations/single_association'
require 'dynamoid/associations/many_association'
require 'dynamoid/associations/has_many'
require 'dynamoid/associations/belongs_to'
require 'dynamoid/associations/has_one'
require 'dynamoid/associations/has_and_belongs_to_many'

module Dynamoid
  # Connects models together through the magic of associations. We enjoy four different kinds of associations presently:
  #   * belongs_to
  #   * has_and_belongs_to_many
  #   * has_many
  #   * has_one
  module Associations
    extend ActiveSupport::Concern

    # Create the association tracking attribute and initialize it to an empty hash.
    included do
      class_attribute :associations, instance_accessor: false

      self.associations = {}
    end

    module ClassMethods
      # Declare a +has_many+ association for this document.
      #
      #   class Category
      #     include Dynamoid::Document
      #
      #     has_many :posts
      #   end
      #
      # Association is an enumerable collection and supports following addition
      # operations:
      #
      # * +create+
      # * +create!+
      # * +destroy_all+
      # * +delete_all+
      # * +delete+
      # * +<<+
      # * +where+
      # * +all+
      # * +empty?+
      # * +size+
      #
      # When a name of an associated class doesn't match an association name a
      # class name should be specified explicitly either with +class+ or
      # +class_name+ option:
      #
      #   has_many :labels, class: Tag
      #   has_many :labels, class_name: 'Tag'
      #
      # When associated class has own +belongs_to+ association to
      # the current class and the name doesn't match a name of the current
      # class this name can be specified with +inverse_of+ option:
      #
      #   class Post
      #     include Dynamoid::Document
      #
      #     belongs_to :item, class_name: 'Tag'
      #   end
      #
      #   class Tag
      #     include Dynamoid::Document
      #
      #     has_many :posts, inverse_of: :item
      #   end
      #
      # @param name [Symbol] the name of the association
      # @param options [Hash] options to pass to the association constructor
      # @option options [Class] :class the target class of the has_many association; that is, the belongs_to class
      # @option options [String] :class_name the name of the target class of the association; that is, the name of the belongs_to class
      # @option options [Symbol] :inverse_of the name of the association on the target class; that is, if the class has a belongs_to association, the name of that association
      #
      # @since 0.2.0
      def has_many(name, options = {})
        association(:has_many, name, options)
      end

      # Declare a +has_one+ association for this document.
      #
      #   class Image
      #     include Dynamoid::Document
      #
      #     has_one :post
      #   end
      #
      # Association supports following operations:
      #
      # * +create+
      # * +create!+
      # * +delete+
      #
      # When a name of an associated class doesn't match an association name a
      # class name should be specified explicitly either with +class+ or
      # +class_name+ option:
      #
      #   has_one :item, class: Post
      #   has_one :item, class_name: 'Post'
      #
      # When associated class has own +belong_to+ association to the current
      # class and the name doesn't match a name of the current class this name
      # can be specified with +inverse_of+ option:
      #
      #   class Post
      #     include Dynamoid::Document
      #
      #     belongs_to :logo, class_name: 'Image'
      #   end
      #
      #   class Image
      #     include Dynamoid::Document
      #
      #     has_one :post, inverse_of: :logo
      #   end
      #
      # @param name [Symbol] the name of the association
      # @param options [Hash] options to pass to the association constructor
      # @option options [Class] :class the target class of the has_one association; that is, the belongs_to class
      # @option options [String] :class_name the name of the target class of the association; that is, the name of the belongs_to class
      # @option options [Symbol] :inverse_of the name of the association on the target class; that is, if the class has a belongs_to association, the name of that association
      #
      # @since 0.2.0
      def has_one(name, options = {})
        association(:has_one, name, options)
      end

      # Declare a +belongs_to+ association for this document.
      #
      #   class Post
      #     include Dynamoid::Document
      #
      #     belongs_to :categories
      #   end
      #
      # Association supports following operations:
      #
      # * +create+
      # * +create!+
      # * +delete+
      #
      # When a name of an associated class doesn't match an association name a
      # class name should be specified explicitly either with +class+ or
      # +class_name+ option:
      #
      #   belongs_to :item, class: Post
      #   belongs_to :item, class_name: 'Post'
      #
      # When associated class has own +has_many+ or +has_one+ association to
      # the current class and the name doesn't match a name of the current
      # class this name can be specified with +inverse_of+ option:
      #
      #   class Category
      #     include Dynamoid::Document
      #
      #     has_many :items, class_name: 'Post'
      #   end
      #
      #   class Post
      #     include Dynamoid::Document
      #
      #     belongs_to :categories, inverse_of: :items
      #   end
      #
      # By default a hash key attribute name is +id+. If an associated class
      # uses another name for a hash key attribute it should be specified in
      # the +belongs_to+ association:
      #
      #   belongs_to :categories, foreign_key: :uuid
      #
      # @param name [Symbol] the name of the association
      # @param options [Hash] options to pass to the association constructor
      # @option options [Class] :class the target class of the has_one association; that is, the has_many or has_one class
      # @option options [String] :class_name the name of the target class of the association; that is, the name of the has_many or has_one class
      # @option options [Symbol] :inverse_of the name of the association on the target class; that is, if the class has a has_many or has_one association, the name of that association
      # @option options [Symbol] :foreign_key the name of a hash key attribute in the target class
      #
      # @since 0.2.0
      def belongs_to(name, options = {})
        association(:belongs_to, name, options)
      end

      # Declare a +has_and_belongs_to_many+ association for this document.
      #
      #   class Post
      #     include Dynamoid::Document
      #
      #     has_and_belongs_to_many :tags
      #   end
      #
      # Association is an enumerable collection and supports following addition
      # operations:
      #
      # * +create+
      # * +create!+
      # * +destroy_all+
      # * +delete_all+
      # * +delete+
      # * +<<+
      # * +where+
      # * +all+
      # * +empty?+
      # * +size+
      #
      # When a name of an associated class doesn't match an association name a
      # class name should be specified explicitly either with +class+ or
      # +class_name+ option:
      #
      #   has_and_belongs_to_many :labels, class: Tag
      #   has_and_belongs_to_many :labels, class_name: 'Tag'
      #
      # When associated class has own +has_and_belongs_to_many+ association to
      # the current class and the name doesn't match a name of the current
      # class this name can be specified with +inverse_of+ option:
      #
      #   class Tag
      #     include Dynamoid::Document
      #
      #     has_and_belongs_to_many :items, class_name: 'Post'
      #   end
      #
      #   class Post
      #     include Dynamoid::Document
      #
      #     has_and_belongs_to_many :tags, inverse_of: :items
      #   end
      #
      # @param name [Symbol] the name of the association
      # @param options [Hash] options to pass to the association constructor
      # @option options [Class] :class the target class of the has_and_belongs_to_many association; that is, the belongs_to class
      # @option options [String] :class_name the name of the target class of the association; that is, the name of the belongs_to class
      # @option options [Symbol] :inverse_of the name of the association on the target class; that is, if the class has a belongs_to association, the name of that association
      #
      # @since 0.2.0
      def has_and_belongs_to_many(name, options = {})
        association(:has_and_belongs_to_many, name, options)
      end

      private

      # create getters and setters for an association.
      #
      # @param type [Symbol] the type (:has_one, :has_many, :has_and_belongs_to_many, :belongs_to) of the association
      # @param name [Symbol] the name of the association
      # @param options [Hash] options to pass to the association constructor; see above for all valid options
      #
      # @since 0.2.0
      def association(type, name, options = {})
        # Declare document field.
        # In simple case it's equivalent to
        # field "#{name}_ids".to_sym, :set
        assoc = Dynamoid::Associations.const_get(type.to_s.camelcase).new(nil, name, options)
        field_name = assoc.declaration_field_name
        field_type = assoc.declaration_field_type

        field field_name.to_sym, field_type

        associations[name] = options.merge(type: type)

        define_method(name) do
          @associations[:"#{name}_ids"] ||= Dynamoid::Associations.const_get(type.to_s.camelcase).new(self, name, options)
        end

        define_method("#{name}=".to_sym) do |objects|
          @associations[:"#{name}_ids"] ||= Dynamoid::Associations.const_get(type.to_s.camelcase).new(self, name, options)
          @associations[:"#{name}_ids"].setter(objects)
        end
      end
    end
  end
end
