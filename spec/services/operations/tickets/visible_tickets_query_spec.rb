# rubocop:disable Metrics/BlockLength
require "rails_helper"

RSpec.describe Operations::Tickets::VisibleTicketsQuery do
  describe ".call" do
    let(:hotel) { create(:hotel) }
    let(:other_hotel) { create(:hotel) }
    let(:manager) { create(:staff, :manager, hotel: hotel) }
    let(:department) { create(:department, hotel: hotel) }
    let(:other_department) { create(:department, hotel: hotel) }
    let(:cross_hotel_department) { create(:department, hotel: other_hotel) }
    let(:staff_user) { create(:staff, hotel: hotel, department: department) }
    let(:other_staff_user) { create(:staff, hotel: hotel, department: other_department) }

    it "returns all same-hotel tickets for managers" do
      visible_ticket = create(:ticket, hotel: hotel, department: department, staff: nil)
      other_visible_ticket = create(:ticket, hotel: hotel, department: other_department, staff: nil)
      create(:ticket, hotel: other_hotel, department: cross_hotel_department, staff: nil)

      result = described_class.call(staff: manager)

      expect(result).to contain_exactly(visible_ticket, other_visible_ticket)
    end

    it "returns personally assigned tickets for staff" do
      assigned_ticket = create(:ticket, hotel: hotel, department: other_department, staff: staff_user)
      create(:ticket, hotel: hotel, department: other_department, staff: other_staff_user)

      result = described_class.call(staff: staff_user)

      expect(result).to include(assigned_ticket)
    end

    it "returns same-department tickets for staff" do
      same_department_ticket = create(:ticket, hotel: hotel, department: department, staff: nil)

      result = described_class.call(staff: staff_user)

      expect(result).to include(same_department_ticket)
    end

    it "excludes unrelated same-hotel departments for staff" do
      create(:ticket, hotel: hotel, department: department, staff: nil)
      unrelated_ticket = create(:ticket, hotel: hotel, department: other_department, staff: nil)

      result = described_class.call(staff: staff_user)

      expect(result).not_to include(unrelated_ticket)
    end

    it "excludes cross-hotel tickets for staff" do
      create(:ticket, hotel: hotel, department: department, staff: nil)
      cross_hotel_ticket = create(:ticket, hotel: other_hotel, department: cross_hotel_department, staff: nil)

      result = described_class.call(staff: staff_user)

      expect(result).not_to include(cross_hotel_ticket)
    end
  end
end
# rubocop:enable Metrics/BlockLength
