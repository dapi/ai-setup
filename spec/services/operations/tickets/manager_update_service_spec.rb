# rubocop:disable Metrics/BlockLength
require "rails_helper"

RSpec.describe Operations::Tickets::ManagerUpdateService do
  describe ".call" do
    let(:hotel) { create(:hotel) }
    let(:other_hotel) { create(:hotel) }
    let(:manager) { create(:staff, :manager, hotel: hotel) }
    let(:department) { create(:department, hotel: hotel) }
    let(:guest) { create(:guest, hotel: hotel) }
    let(:ticket) { create(:ticket, hotel: hotel, guest: guest, department: department, staff: nil) }
    let(:assignee) { create(:staff, hotel: hotel) }

    it "assigns a same-hotel staff user" do
      result = described_class.call(manager: manager, ticket: ticket, params: { staff_id: assignee.id })

      expect(result).to be_success
      expect(ticket.reload.staff).to eq(assignee)
    end

    it "reassigns a ticket" do
      old_assignee = create(:staff, hotel: hotel)
      ticket.update!(staff: old_assignee)

      result = described_class.call(manager: manager, ticket: ticket, params: { staff_id: assignee.id })

      expect(result).to be_success
      expect(ticket.reload.staff).to eq(assignee)
    end

    it "unassigns a ticket with blank staff_id" do
      ticket.update!(staff: assignee)

      result = described_class.call(manager: manager, ticket: ticket, params: { staff_id: "" })

      expect(result).to be_success
      expect(ticket.reload.staff).to be_nil
    end

    it "updates status without changing assignment when staff_id is absent" do
      ticket.update!(staff: assignee)

      result = described_class.call(manager: manager, ticket: ticket, params: { status: "in_progress" })

      expect(result).to be_success
      expect(ticket.reload.status).to eq("in_progress")
      expect(ticket.staff).to eq(assignee)
    end

    it "denies cross-hotel assignees" do
      other_assignee = create(:staff, hotel: other_hotel)

      result = described_class.call(manager: manager, ticket: ticket, params: { staff_id: other_assignee.id })

      expect(result).to be_failure
      expect(result.messages).to include("Staff must belong to the same hotel")
      expect(ticket.reload.staff).to be_nil
    end

    it "denies non-staff assignees" do
      non_staff_assignee = create(:staff, :manager, hotel: hotel)

      result = described_class.call(manager: manager, ticket: ticket, params: { staff_id: non_staff_assignee.id })

      expect(result).to be_failure
      expect(result.messages).to include("Staff must have staff role")
      expect(ticket.reload.staff).to be_nil
    end

    it "returns failure for invalid status" do
      result = described_class.call(manager: manager, ticket: ticket, params: { status: "invalid" })

      expect(result).to be_failure
      expect(result.messages).to include("Status is invalid")
      expect(ticket.reload.status).to eq("new")
    end

    it "denies cross-hotel tickets" do
      other_department = create(:department, hotel: other_hotel)
      other_guest = create(:guest, hotel: other_hotel)
      other_ticket = create(:ticket, hotel: other_hotel, guest: other_guest, department: other_department, staff: nil)

      result = described_class.call(manager: manager, ticket: other_ticket, params: { status: "in_progress" })

      expect(result).to be_failure
      expect(result.error_code).to eq(:forbidden)
      expect(other_ticket.reload.status).to eq("new")
    end

    it "ignores disallowed attributes" do
      other_department = create(:department, hotel: hotel)
      other_guest = create(:guest, hotel: hotel)

      result = described_class.call(
        manager: manager,
        ticket: ticket,
        params: {
          staff_id: assignee.id,
          guest_id: other_guest.id,
          hotel_id: other_hotel.id,
          department_id: other_department.id,
          subject: "Changed",
          body: "Changed",
          priority: "high"
        }
      )

      expect(result).to be_success
      ticket.reload
      expect(ticket.staff).to eq(assignee)
      expect(ticket.guest).to eq(guest)
      expect(ticket.hotel).to eq(hotel)
      expect(ticket.department).to eq(department)
      expect(ticket.subject).to eq("Test subject")
      expect(ticket.body).to eq("Test body")
      expect(ticket.priority).to eq("medium")
    end
  end
end
# rubocop:enable Metrics/BlockLength
