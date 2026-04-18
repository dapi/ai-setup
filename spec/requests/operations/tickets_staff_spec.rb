# rubocop:disable Metrics/BlockLength
require "rails_helper"

RSpec.describe "Operations staff tickets" do
  let(:hotel) { create(:hotel) }
  let(:other_hotel) { create(:hotel) }
  let(:department) { create(:department, hotel: hotel, name: "Housekeeping") }
  let(:other_department) { create(:department, hotel: hotel, name: "Restaurant") }
  let(:unrelated_department) { create(:department, hotel: hotel, name: "Maintenance") }
  let(:cross_hotel_department) { create(:department, hotel: other_hotel, name: "Cross Hotel Department") }
  let(:staff_user) { create(:staff, hotel: hotel, department: department) }
  let(:guest) { create(:guest, hotel: hotel) }
  let(:other_guest) { create(:guest, hotel: other_hotel) }

  describe "GET /operations/tickets" do
    it "includes personally assigned tickets" do
      assigned_ticket = create(:ticket, hotel: hotel, guest: guest, department: other_department, staff: staff_user)
      create(:ticket, hotel: hotel, guest: guest, department: unrelated_department, staff: nil)

      get operations_tickets_path, headers: auth_header(staff_user)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(operations_ticket_path(assigned_ticket), "Restaurant")
    end

    it "includes same-department tickets" do
      same_department_ticket = create(:ticket, hotel: hotel, guest: guest, department: department, staff: nil)

      get operations_tickets_path, headers: auth_header(staff_user)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(operations_ticket_path(same_department_ticket), "Housekeeping")
    end

    it "excludes unrelated department tickets" do
      create(:ticket, hotel: hotel, guest: guest, department: department, staff: nil)
      create(:ticket, hotel: hotel, guest: guest, department: unrelated_department, staff: nil)

      get operations_tickets_path, headers: auth_header(staff_user)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Maintenance")
    end

    it "excludes cross-hotel tickets" do
      create(:ticket, hotel: hotel, guest: guest, department: department, staff: nil)
      create(:ticket, hotel: other_hotel, guest: other_guest, department: cross_hotel_department, staff: nil)

      get operations_tickets_path, headers: auth_header(staff_user)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Cross Hotel Department")
    end
  end

  describe "GET /operations/tickets/:id" do
    it "shows personally assigned tickets" do
      ticket = create(:ticket, hotel: hotel, guest: guest, department: other_department, staff: staff_user)

      get operations_ticket_path(ticket), headers: auth_header(staff_user)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(ticket.id.to_s, "Restaurant", ticket.subject)
    end

    it "shows same-department tickets" do
      ticket = create(:ticket, hotel: hotel, guest: guest, department: department, staff: nil)

      get operations_ticket_path(ticket), headers: auth_header(staff_user)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(ticket.id.to_s, "Housekeeping", ticket.subject)
    end

    it "returns 404 for unrelated same-hotel tickets" do
      ticket = create(:ticket, hotel: hotel, guest: guest, department: unrelated_department, staff: nil)

      get operations_ticket_path(ticket), headers: auth_header(staff_user)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "manager-only actions" do
    it "returns 403 for edit" do
      ticket = create(:ticket, hotel: hotel, guest: guest, department: department, staff: nil)

      get edit_operations_ticket_path(ticket), headers: auth_header(staff_user)

      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for update" do
      ticket = create(:ticket, hotel: hotel, guest: guest, department: department, staff: nil)

      patch operations_ticket_path(ticket), headers: auth_header(staff_user), params: { ticket: { status: "done" } }

      expect(response).to have_http_status(:forbidden)
    end
  end
end
# rubocop:enable Metrics/BlockLength
