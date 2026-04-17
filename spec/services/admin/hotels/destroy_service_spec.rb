require "rails_helper"

RSpec.describe Admin::Hotels::DestroyService do
  describe ".call" do
    it "destroys a hotel without associated records" do
      hotel = create(:hotel)

      expect do
        result = described_class.call(hotel: hotel)

        expect(result).to be_success
        expect(result.result).to eq(hotel)
      end.to change(Hotel, :count).by(-1)
    end

    it "returns a failure when associated records prevent deletion" do
      hotel = create(:hotel)
      create(:staff, :admin, hotel: hotel)

      expect do
        result = described_class.call(hotel: hotel)

        expect(result).to be_failure
        expect(result.error_code).to eq(:associated_records_exist)
        expect(result.messages).to include(I18n.t("admin.hotels.destroy.associated_records_exist"))
        expect(result.result).to eq(hotel)
      end.not_to change(Hotel, :count)
    end
  end
end
