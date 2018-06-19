# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dynamoid::Config::BackoffStrategies::ExponentialBackoff do
  let(:base_backoff) { 1 }
  let(:ceiling) { 5 }
  let(:backoff) { described_class.call(base_backoff: base_backoff, ceiling: ceiling) }

  it 'sleeps the first time for specified base backoff time' do
    expect(described_class).to receive(:sleep).with(base_backoff)
    backoff.call
  end

  it 'sleeps for exponentialy increasing time' do
    seconds = []
    allow(described_class).to receive(:sleep) do |s|
      seconds << s
    end

    backoff.call
    expect(seconds).to eq [base_backoff]

    backoff.call
    expect(seconds).to eq [base_backoff, base_backoff * 2]

    backoff.call
    expect(seconds).to eq [base_backoff, base_backoff * 2, base_backoff * 4]

    backoff.call
    expect(seconds).to eq [base_backoff, base_backoff * 2, base_backoff * 4, base_backoff * 8]
  end

  it 'stops to increase time after ceiling times' do
    seconds = []
    allow(described_class).to receive(:sleep) do |s|
      seconds << s
    end

    6.times { backoff.call }
    expect(seconds).to eq [
      base_backoff,
      base_backoff * 2,
      base_backoff * 4,
      base_backoff * 8,
      base_backoff * 16,
      base_backoff * 16
    ]
  end

  it 'can be called without parameters' do
    backoff = nil
    expect do
      backoff = described_class.call
    end.not_to raise_error
  end

  it 'uses base backoff = 0.5 and ceiling = 3 by default' do
    backoff = described_class.call

    seconds = []
    allow(described_class).to receive(:sleep) do |s|
      seconds << s
    end

    4.times { backoff.call }
    expect(seconds).to eq([
                            0.5,
                            0.5 * 2,
                            0.5 * 4,
                            0.5 * 4
                          ])
  end
end
