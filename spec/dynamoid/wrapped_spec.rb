# frozen_string_literal: true

require 'spec_helper'

describe 'Dynamoid with adapter' do
  let(:document) { Wrapper.create(wrapped: Wrapper::Wrapped.new(foo: 'foo', bar: 'bar')) }

  describe "#create" do
    it "saves document" do
      expect(document).to be_persisted
    end
  end

  describe "#find" do
    it "can deserialize" do
      loaded = Wrapper.find(document.id)
      expect(loaded.wrapped).to be_an_instance_of(Wrapper::Wrapped)
      expect(loaded.wrapped).to have_attributes(foo: 'foo', bar: 'bar')
      expect(loaded).to have_attributes(foo: 'foo', bar: 'bar')
    end
  end

  describe "#save!" do
    it "can make changes" do
      document.foo = 'changed'
      document.save!
      document.reload
      expect(document).to have_attributes(foo: 'changed', bar: 'bar')
    end
  end
end