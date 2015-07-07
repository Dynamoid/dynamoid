require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "Dynamoid" do

  it "doesn't puke when asked for the assocations of a new record" do
    expect(User.new.books).to eq([])
  end

  it "doesn't connect automatically when configured" do
    expect(Dynamoid::Adapter).to receive(:reconnect!).never
    Dynamoid.configure { |config| nil }
  end

end
