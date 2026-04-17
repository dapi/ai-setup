require "rails_helper"

RSpec.describe Admin::Hotels::CreateService do
  describe ".call" do
    it "creates a hotel with an auto-generated slug" do
      result = described_class.call(params: { name: "Grand Palace", timezone: "Europe/Moscow" })

      expect(result).to be_success
      expect(result.result).to be_persisted
      expect(result.result.slug).to eq("grand-palace-slug")
    end

    it "returns validation errors when the hotel is invalid" do
      result = described_class.call(params: { name: "", timezone: "" })

      expect(result).to be_failure
      expect(result.error_code).to eq(:validation_failed)
      expect(result.messages).to include("Name can't be blank", "Timezone can't be blank")
      expect(result.result).not_to be_persisted
    end

    it "returns validation errors when timezone is missing" do
      result = described_class.call(params: { name: "Grand Palace", timezone: "" })

      expect(result).to be_failure
      expect(result.error_code).to eq(:validation_failed)
      expect(result.messages).to include("Timezone can't be blank")
      expect(result.result).not_to be_persisted
    end

    it "returns validation errors when name and generated slug are duplicates" do
      create(:hotel, name: "Grand Palace", slug: "grand-palace-slug")

      result = described_class.call(params: { name: "Grand Palace", timezone: "Europe/Moscow" })

      expect(result).to be_failure
      expect(result.error_code).to eq(:validation_failed)
      expect(result.messages).to include("Name has already been taken", "Slug has already been taken")
      expect(result.result).not_to be_persisted
    end
  end
end
