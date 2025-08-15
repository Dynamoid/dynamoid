# frozen_string_literal: true

require 'spec_helper'
require 'fixtures/persistence'

RSpec.describe Dynamoid::Persistence do
  describe '#touch' do
    it 'assigns updated_at attribute to current time' do
      klass = new_class
      obj = klass.create

      travel 1.hour do
        obj.touch
        expect(obj.updated_at.to_i).to eq(Time.now.to_i)
      end
    end

    it 'saves updated_at attribute value' do
      klass = new_class
      obj = klass.create

      travel 1.hour do
        obj.touch

        obj_persistes = klass.find(obj.id)
        expect(obj_persistes.updated_at.to_i).to eq(Time.now.to_i)
      end
    end

    it 'returns self' do
      klass = new_class
      obj = klass.create
      expect(obj.touch).to eq obj
    end

    it 'assigns and saves specified time' do
      klass = new_class
      obj = klass.create

      time = Time.now + 1.day
      obj.touch(time: time)

      obj_persistes = klass.find(obj.id)
      expect(obj.updated_at.to_i).to eq(time.to_i)
      expect(obj_persistes.updated_at.to_i).to eq(time.to_i)
    end

    it 'assignes and saves also specified timestamp attributes' do
      klass = new_class do
        field :tagged_at, :datetime
        field :logged_in_at, :datetime
      end
      obj = klass.create

      travel 1.hour do
        obj.touch(:tagged_at, :logged_in_at)

        obj_persistes = klass.find(obj.id)

        expect(obj.updated_at.to_i).to eq(Time.now.to_i)
        expect(obj_persistes.updated_at.to_i).to eq(Time.now.to_i)

        expect(obj.tagged_at.to_i).to eq(Time.now.to_i)
        expect(obj_persistes.tagged_at.to_i).to eq(Time.now.to_i)

        expect(obj.logged_in_at.to_i).to eq(Time.now.to_i)
        expect(obj_persistes.logged_in_at.to_i).to eq(Time.now.to_i)
      end
    end

    it 'does not save other changed attributes' do
      klass = new_class do
        field :name
      end

      obj = klass.create(name: 'Alex')
      obj.name = 'Michael'

      travel 1.hour do
        obj.touch

        obj_persisted = klass.find(obj.id)
        expect(obj_persisted.name).to eq 'Alex'
      end
    end

    it 'does not validate' do
      klass_with_validation = new_class do
        field :name
        validates :name, length: { minimum: 4 }
      end

      obj = klass_with_validation.create(name: 'Theodor')
      obj.name = 'Mo'

      travel 1.hour do
        obj.touch

        obj_persistes = klass_with_validation.find(obj.id)
        expect(obj_persistes.updated_at.to_i).to eq(Time.now.to_i)
      end
    end

    it 'raise Dynamoid::Error when not persisted model' do
      klass = new_class
      obj = klass.new

      expect {
        obj.touch
      }.to raise_error(Dynamoid::Errors::Error, 'cannot touch on a new or destroyed record object')
    end

    describe 'callbacks' do
      it 'runs callbacks in the proper order' do
        klass_with_callbacks = new_class do
          before_validation { puts 'run before_validation' }
          after_validation { puts 'run after_validation' }

          before_update { puts 'run before_update' }
          after_update { puts 'run after_update' }
          around_update :around_update_callback

          before_save { puts 'run before_save' }
          after_save { puts 'run after_save' }
          around_save :around_save_callback

          after_touch { puts 'run after_touch' }

          def around_save_callback
            puts 'start around_save'
            yield
            puts 'finish around_save'
          end

          def around_update_callback
            puts 'start around_update'
            yield
            puts 'finish around_update'
          end
        end

        expect { # to suppress printing at model creation
          obj = klass_with_callbacks.create
          expect { obj.touch }.to output("run after_touch\n").to_stdout
        }.to output.to_stdout
      end
    end
  end
end
