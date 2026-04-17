require "rails_helper"

RSpec.describe Admin::Hotels::SlugGenerator do
  describe ".call" do
    it "generates the configured hotel slug format" do
      expect(described_class.call(name: "Grand Palace")).to eq("grand-palace-slug")
    end
  end
end
