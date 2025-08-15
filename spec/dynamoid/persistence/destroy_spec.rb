# frozen_string_literal: true

require 'spec_helper'
require 'fixtures/persistence'

RSpec.describe Dynamoid::Persistence do
  describe 'destroy' do
    # TODO: adopt test cases for the `delete` method

    it 'does not raise exception when model does not exist' do
      klass = new_class
      obj = klass.create
      obj2 = klass.find(obj.id)
      obj.delete
      expect(klass.exists?(obj.id)).to eql false

      obj2.destroy
      expect(obj2.destroyed?).to eql true
    end

    describe 'callbacks' do
      it 'runs before_destroy callback' do
        klass_with_callback = new_class do
          before_destroy { print 'run before_destroy' }
        end

        obj = klass_with_callback.create

        expect { obj.destroy }.to output('run before_destroy').to_stdout
      end

      it 'runs after_destroy callback' do
        klass_with_callback = new_class do
          after_destroy { print 'run after_destroy' }
        end

        obj = klass_with_callback.create
        expect { obj.destroy }.to output('run after_destroy').to_stdout
      end

      it 'runs around_destroy callback' do
        klass_with_callback = new_class do
          around_destroy :around_destroy_callback

          def around_destroy_callback
            print 'start around_destroy'
            yield
            print 'finish around_destroy'
          end
        end

        obj = klass_with_callback.create

        expect { obj.destroy }.to output('start around_destroyfinish around_destroy').to_stdout
      end

      it 'aborts destroying and returns false if a before_destroy callback throws :abort' do
        if ActiveSupport.version < Gem::Version.new('5.0')
          skip "Rails 4.x and below don't support aborting with `throw :abort`"
        end

        klass = new_class do
          before_destroy { throw :abort }
        end
        obj = klass.create!

        result = nil
        expect {
          result = obj.destroy
        }.not_to change { klass.count }

        expect(result).to eql false
        # expect(obj.destroyed?).to eql false # FIXME
      end
    end
  end

  describe 'destroy!' do
    it 'aborts destroying and raises RecordNotDestroyed if a before_destroy callback throws :abort' do
      if ActiveSupport.version < Gem::Version.new('5.0')
        skip "Rails 4.x and below don't support aborting with `throw :abort`"
      end

      klass = new_class do
        before_destroy { throw :abort }
      end
      obj = klass.create!

      expect {
        expect {
          obj.destroy!
        }.to raise_error(Dynamoid::Errors::RecordNotDestroyed)
      }.not_to change { klass.count }

      # expect(obj.destroyed?).to eql false # FIXME
    end
  end
end
