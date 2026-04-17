require "rails_helper"

RSpec.describe Admin::Hotels::TicketsQuery do
  describe ".call" do
    it "returns only tickets with associations from the requested hotel" do
      hotel = create(:hotel)
      other_hotel = create(:hotel)
      guest = create(:guest, hotel: hotel)
      department = create(:department, hotel: hotel)
      staff = create(:staff, hotel: hotel)
      valid_ticket = create(:ticket, hotel: hotel, guest: guest, department: department, staff: staff)

      other_ticket = create(:ticket, hotel: other_hotel)
      invalid_ticket = create(:ticket, hotel: hotel, guest: guest, department: department, staff: nil)
      invalid_ticket.update_columns(staff_id: create(:staff, hotel: other_hotel).id)

      result = described_class.call(hotel: hotel)

      expect(result).to contain_exactly(valid_ticket)
      expect(result).not_to include(other_ticket, invalid_ticket)
    end
  end
end
