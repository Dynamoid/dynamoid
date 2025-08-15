# frozen_string_literal: true

require 'spec_helper'
require 'fixtures/persistence'

RSpec.describe Dynamoid::Persistence do
  describe '#persisted?' do
    before do
      klass.create_table
    end

    let(:klass) do
      new_class
    end

    it 'returns true for saved model' do
      model = klass.create!
      expect(model.persisted?).to eq true
    end

    it 'returns false for new model' do
      model = klass.new
      expect(model.persisted?).to eq false
    end

    it 'returns false for deleted model' do
      model = klass.create!

      model.delete
      expect(model.persisted?).to eq false
    end

    it 'returns false for destroyed model' do
      model = klass.create!

      model.destroy
      expect(model.persisted?).to eq false
    end
  end
end
