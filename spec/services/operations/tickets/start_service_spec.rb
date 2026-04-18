# rubocop:disable Metrics/BlockLength
require "rails_helper"

RSpec.describe Operations::Tickets::StartService do
  describe ".call" do
    let(:hotel) { create(:hotel) }
    let(:other_hotel) { create(:hotel) }
    let(:department) { create(:department, hotel: hotel) }
    let(:staff_user) { create(:staff, hotel: hotel, department: department) }

    it "starts an assigned new ticket" do
      ticket = create(:ticket, hotel: hotel, department: department, staff: staff_user, status: :new)

      result = described_class.call(staff: staff_user, ticket: ticket)

      expect(result).to be_success
      expect(ticket.reload.status).to eq("in_progress")
    end

    it "denies unassigned tickets" do
      other_department = create(:department, hotel: hotel)
      ticket = create(:ticket, hotel: hotel, department: other_department, staff: nil, status: :new)

      result = described_class.call(staff: staff_user, ticket: ticket)

      expect(result).to be_failure
      expect(result.messages).to include("Ticket must be assigned to staff")
      expect(ticket.reload.status).to eq("new")
    end

    it "denies same-department unassigned tickets" do
      ticket = create(:ticket, hotel: hotel, department: department, staff: nil, status: :new)

      result = described_class.call(staff: staff_user, ticket: ticket)

      expect(result).to be_failure
      expect(result.messages).to include("Ticket must be assigned to staff")
      expect(ticket.reload.status).to eq("new")
    end

    it "denies cross-hotel tickets" do
      other_department = create(:department, hotel: other_hotel)
      other_staff = create(:staff, hotel: other_hotel, department: other_department)
      ticket = create(:ticket, hotel: other_hotel, department: other_department, staff: other_staff, status: :new)

      result = described_class.call(staff: staff_user, ticket: ticket)

      expect(result).to be_failure
      expect(result.messages).to include("Ticket must belong to the same hotel")
      expect(ticket.reload.status).to eq("new")
    end

    it "denies non-staff actors" do
      manager = create(:staff, :manager, hotel: hotel)
      ticket = create(:ticket, hotel: hotel, department: department, staff: manager, status: :new)

      result = described_class.call(staff: manager, ticket: ticket)

      expect(result).to be_failure
      expect(result.messages).to include("Actor must have staff role")
      expect(ticket.reload.status).to eq("new")
    end

    it "denies invalid transitions" do
      ticket = create(:ticket, hotel: hotel, department: department, staff: staff_user, status: :done)

      result = described_class.call(staff: staff_user, ticket: ticket)

      expect(result).to be_failure
      expect(result.messages).to include("Ticket cannot be started")
      expect(ticket.reload.status).to eq("done")
    end
  end
end
# rubocop:enable Metrics/BlockLength
