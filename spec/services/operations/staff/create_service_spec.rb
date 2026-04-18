# rubocop:disable Metrics/BlockLength
require "rails_helper"

RSpec.describe Operations::Staff::CreateService do
  describe ".call" do
    let(:hotel) { create(:hotel) }
    let(:other_hotel) { create(:hotel) }
    let(:manager) { create(:staff, :manager, hotel: hotel) }
    let(:department) { create(:department, hotel: hotel) }
    let(:other_department) { create(:department, hotel: other_hotel) }

    it "creates staff for the manager hotel" do
      result = described_class.call(manager: manager, params: valid_params)

      expect(result).to be_success
      expect(result.result).to be_persisted
      expect(result.result.hotel).to eq(hotel)
      expect(result.result.department).to eq(department)
    end

    it "forces the manager hotel" do
      result = described_class.call(manager: manager, params: valid_params.merge(hotel_id: other_hotel.id))

      expect(result).to be_success
      expect(result.result.hotel).to eq(hotel)
    end

    it "forces the staff role" do
      result = described_class.call(manager: manager, params: valid_params.merge(role: :admin))

      expect(result).to be_success
      expect(result.result).to be_staff
    end

    it "returns validation errors for duplicate email" do
      create(:staff, hotel: hotel, email: "new.staff@example.com")

      result = described_class.call(manager: manager, params: valid_params)

      expect(result).to be_failure
      expect(result.error_code).to eq(:validation_failed)
      expect(result.messages).to include("Email has already been taken")
      expect(result.result).not_to be_persisted
    end

    it "denies cross-hotel departments" do
      result = described_class.call(manager: manager, params: valid_params.merge(department_id: other_department.id))

      expect(result).to be_failure
      expect(result.error_code).to eq(:validation_failed)
      expect(result.messages).to include("Department must belong to the same hotel")
      expect(result.result).not_to be_persisted
    end

    it "returns validation errors when department is missing" do
      result = described_class.call(manager: manager, params: valid_params.except(:department_id))

      expect(result).to be_failure
      expect(result.messages).to include("Department can't be blank")
      expect(result.result).not_to be_persisted
    end

    it "keeps the staff role when role params try to bypass department requirements" do
      result = described_class.call(manager: manager, params: valid_params.except(:department_id).merge(role: :manager))

      expect(result).to be_failure
      expect(result.result).to be_staff
      expect(result.messages).to include("Department can't be blank")
    end

    it "ignores unpermitted attributes" do
      result = described_class.call(
        manager: manager,
        params: valid_params.merge(role: :admin, hotel_id: other_hotel.id, id: 123)
      )

      expect(result).to be_success
      expect(result.result).to be_staff
      expect(result.result.hotel).to eq(hotel)
      expect(result.result.id).not_to eq(123)
    end

    def valid_params
      {
        name: "New Staff",
        email: "new.staff@example.com",
        password: "password",
        password_confirmation: "password",
        department_id: department.id
      }
    end
  end
end
# rubocop:enable Metrics/BlockLength
