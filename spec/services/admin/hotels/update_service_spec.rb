require "rails_helper"

RSpec.describe Admin::Hotels::UpdateService do
  describe ".call" do
    let!(:hotel) { create(:hotel, name: "Grand Palace", slug: "grand-palace-slug", timezone: "UTC") }

    it "updates only permitted attributes" do
      result = described_class.call(hotel: hotel, params: { name: "Aurora", timezone: "Europe/London" })

      expect(result).to be_success
      expect(result.result.name).to eq("Aurora")
      expect(result.result.timezone).to eq("Europe/London")
      expect(result.result.slug).to eq("grand-palace-slug")
    end

    it "returns validation errors when the hotel is invalid" do
      result = described_class.call(hotel: hotel, params: { name: "", timezone: "" })

      expect(result).to be_failure
      expect(result.error_code).to eq(:validation_failed)
      expect(result.messages).to include("Name can't be blank", "Timezone can't be blank")
      expect(result.result.slug).to eq("grand-palace-slug")
    end
  end
end
