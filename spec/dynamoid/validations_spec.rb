# frozen_string_literal: true

require 'spec_helper'

describe Dynamoid::Validations do
  let(:doc_class) do
    new_class
  end

  it 'validates presence of' do
    doc_class.field :name
    doc_class.validates_presence_of :name
    doc = doc_class.new
    expect(doc.save).to be_falsey
    expect(doc.new_record).to be_truthy
    doc.name = 'secret'
    expect(doc.save).to_not be_falsey
    expect(doc.errors).to be_empty
  end

  it 'validates presence of boolean field' do
    doc_class.field :flag, :boolean
    doc_class.validates_presence_of :flag
    doc = doc_class.new
    expect(doc.save).to be_falsey
    doc.flag = false
    expect(doc.save).to_not be_falsey
    expect(doc.errors).to be_empty
  end

  it 'raises document not found' do
    doc_class.field :name
    doc_class.validates_presence_of :name
    doc = doc_class.new
    expect { doc.save! }.to raise_error(Dynamoid::Errors::DocumentNotValid) do |error|
      expect(error.document).to eq doc
    end

    expect { doc_class.create! }.to raise_error(Dynamoid::Errors::DocumentNotValid)

    doc = doc_class.create!(name: 'test')
    expect(doc.errors).to be_empty
  end

  it 'does not validate when saves if `validate` option is false' do
    klass = new_class do
      field :name
      validates :name, presence: true
    end

    model = klass.new
    model.save(validate: false)
    expect(model).to be_persisted
  end

  it 'returns true if model is valid' do
    klass = new_class do
      field :name
      validates :name, presence: true
    end

    expect(klass.new(name: 'some-name').save).to eq(true)
  end

  it 'returns false if model is invalid' do
    klass = new_class do
      field :name
      validates :name, presence: true
    end

    expect(klass.new(name: nil).save).to eq(false)
  end

  describe 'save!' do
    it 'returns self' do
      klass = new_class

      model = klass.new
      expect(model.save!).to eq(model)
    end
  end
end
