# frozen_string_literal: true

require 'spec_helper'

# Dynamoid.config.logger.level = :debug

RSpec.shared_context 'transaction_write' do
  let(:klass) do
    new_class(class_name: 'Document') do
      field :name
    end
  end

  let(:klass_with_composite_key) do
    new_class(class_name: 'Cat') do
      range :age, :integer
      field :name
    end
  end

  let(:klass_with_callbacks) do
    new_class(class_name: 'Dog') do
      field :name

      before_save { print 'saving ' }
      after_save { print 'saved ' }
      before_create { print 'creating ' }
      after_create { print 'created ' }
      before_update { print 'updating ' }
      after_update { print 'updated ' }
      before_destroy { print 'destroying ' }
      after_destroy { print 'destroyed ' }
      before_validation { print 'validating ' }
      after_validation { print 'validated ' }
    end
  end

  let(:klass_with_around_callbacks) do
    new_class(class_name: 'Mouse') do
      field :name

      around_save :around_save_callback
      around_create :around_create_callback
      around_update :around_update_callback
      around_destroy :around_destroy_callback
      # no around_validation callback exists

      def around_save_callback
        print 'saving '
        yield
        print 'saved '
      end

      def around_create_callback
        print 'creating '
        yield
        print 'created '
      end

      def around_update_callback
        print 'updating '
        yield
        print 'updated '
      end

      def around_destroy_callback
        print 'destroying '
        yield
        print 'destroyed '
      end
    end
  end

  let(:klass_with_validation) do
    new_class do
      field :name
      validates :name, length: { minimum: 4 }
    end
  end
end
