# frozen_string_literal: true

require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Dynamoid::Associations do
  let(:magazine) { Magazine.create }

  it 'defines a getter' do
    expect(magazine).to respond_to :subscriptions
  end

  it 'defines a setter' do
    expect(magazine).to respond_to :subscriptions=
  end
end
