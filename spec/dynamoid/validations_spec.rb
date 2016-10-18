require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Dynamoid::Validations do
  let(:doc_class) do
    Class.new do
      include Dynamoid::Document

      def self.name
        'Document'
      end
    end
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

    doc = doc_class.create!(:name => 'test')
    expect(doc.errors).to be_empty
  end
end
