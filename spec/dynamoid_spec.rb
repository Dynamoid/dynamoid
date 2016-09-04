require "spec_helper"

describe Dynamoid do
  it "has a version number" do
    expect(Dynamoid::VERSION).not_to be nil
  end

  it "does not puke when asked for the assocations of a new record" do
    expect(User.new.books).to eq([])
  end
end
