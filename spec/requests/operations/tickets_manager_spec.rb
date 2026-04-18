# rubocop:disable Metrics/BlockLength
require "rails_helper"

RSpec.describe "Operations manager tickets" do
  let(:hotel) { create(:hotel) }
  let(:other_hotel) { create(:hotel) }
  let(:manager) { create(:staff, :manager, hotel: hotel) }
  let(:admin) { create(:staff, :admin, hotel: hotel) }
  let(:staff_user) { create(:staff, hotel: hotel, department: department) }
  let(:department) { create(:department, hotel: hotel, name: "Housekeeping") }
  let(:other_department) { create(:department, hotel: hotel, name: "Restaurant") }
  let(:cross_hotel_department) { create(:department, hotel: other_hotel, name: "Cross Hotel Department") }
  let(:guest) { create(:guest, hotel: hotel) }
  let(:other_guest) { create(:guest, hotel: other_hotel) }

  describe "GET /operations/tickets" do
    it "shows all same-hotel tickets to managers" do
      first_ticket = create(:ticket, hotel: hotel, guest: guest, department: department, staff: nil)
      second_ticket = create(:ticket, hotel: hotel, guest: guest, department: other_department, staff: nil)

      get operations_tickets_path, headers: auth_header(manager)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(
        operations_ticket_path(first_ticket),
        operations_ticket_path(second_ticket),
        "Housekeeping",
        "Restaurant"
      )
    end

    it "does not show cross-hotel tickets to managers" do
      create(:ticket, hotel: hotel, guest: guest, department: department, staff: nil)
      create(:ticket, hotel: other_hotel, guest: other_guest, department: cross_hotel_department, staff: nil)

      get operations_tickets_path, headers: auth_header(manager)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Cross Hotel Department")
    end

    it "returns 403 for admins" do
      get operations_tickets_path, headers: auth_header(admin)

      expect(response).to have_http_status(:forbidden)
    end

    it "renders the empty state" do
      get operations_tickets_path, headers: auth_header(manager)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("No tickets found")
    end
  end

  describe "GET /operations/tickets/:id" do
    it "shows same-hotel tickets to managers" do
      ticket = create(:ticket, hotel: hotel, guest: guest, department: department, staff: nil)

      get operations_ticket_path(ticket), headers: auth_header(manager)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(ticket.id.to_s, ticket.status, department.name, ticket.subject, ticket.body)
    end

    it "returns 404 for cross-hotel tickets" do
      ticket = create(:ticket, hotel: other_hotel, guest: other_guest, department: cross_hotel_department, staff: nil)

      get operations_ticket_path(ticket), headers: auth_header(manager)

      expect(response).to have_http_status(:not_found)
    end

    it "returns 403 for admins" do
      ticket = create(:ticket, hotel: hotel, guest: guest, department: department, staff: nil)

      get operations_ticket_path(ticket), headers: auth_header(admin)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "GET /operations/tickets/:id/edit" do
    it "renders only same-hotel staff assignees" do
      ticket = create(:ticket, hotel: hotel, guest: guest, department: department, staff: nil)
      assignee = create(:staff, hotel: hotel, department: department, name: "Alice Staff")
      create(:staff, :manager, hotel: hotel, name: "Bob Manager")
      create(:staff, hotel: other_hotel, name: "Cross Hotel Staff")

      get edit_operations_ticket_path(ticket), headers: auth_header(manager)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Alice Staff")
      expect(response.body).to include(%(value="#{assignee.id}"))
      expect(response.body).not_to include("Bob Manager", "Cross Hotel Staff")
    end

    it "returns 403 for admins" do
      ticket = create(:ticket, hotel: hotel, guest: guest, department: department, staff: nil)

      get edit_operations_ticket_path(ticket), headers: auth_header(admin)

      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for staff" do
      ticket = create(:ticket, hotel: hotel, guest: guest, department: department, staff: nil)

      get edit_operations_ticket_path(ticket), headers: auth_header(staff_user)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "PATCH /operations/tickets/:id" do
    it "assigns tickets" do
      ticket = create(:ticket, hotel: hotel, guest: guest, department: department, staff: nil)

      patch operations_ticket_path(ticket),
            headers: auth_header(manager),
            params: { ticket: { staff_id: staff_user.id } }

      expect(response).to redirect_to(operations_ticket_path(ticket))
      expect(ticket.reload.staff).to eq(staff_user)
    end

    it "reassigns tickets" do
      old_assignee = create(:staff, hotel: hotel, department: department)
      new_assignee = create(:staff, hotel: hotel, department: department)
      ticket = create(:ticket, hotel: hotel, guest: guest, department: department, staff: old_assignee)

      patch operations_ticket_path(ticket),
            headers: auth_header(manager),
            params: { ticket: { staff_id: new_assignee.id } }

      expect(response).to redirect_to(operations_ticket_path(ticket))
      expect(ticket.reload.staff).to eq(new_assignee)
    end

    it "unassigns tickets" do
      ticket = create(:ticket, hotel: hotel, guest: guest, department: department, staff: staff_user)

      patch operations_ticket_path(ticket), headers: auth_header(manager), params: { ticket: { staff_id: "" } }

      expect(response).to redirect_to(operations_ticket_path(ticket))
      expect(ticket.reload.staff).to be_nil
    end

    it "updates status" do
      ticket = create(:ticket, hotel: hotel, guest: guest, department: department, staff: nil, status: :new)

      patch operations_ticket_path(ticket), headers: auth_header(manager), params: { ticket: { status: "in_progress" } }

      expect(response).to redirect_to(operations_ticket_path(ticket))
      expect(ticket.reload.status).to eq("in_progress")
    end

    it "returns 422 for validation failures" do
      ticket = create(:ticket, hotel: hotel, guest: guest, department: department, staff: nil, status: :new)

      patch operations_ticket_path(ticket), headers: auth_header(manager), params: { ticket: { status: "invalid" } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Status is invalid")
      expect(ticket.reload.status).to eq("new")
    end

    it "returns 422 for cross-hotel assignees" do
      ticket = create(:ticket, hotel: hotel, guest: guest, department: department, staff: nil)
      cross_hotel_staff = create(:staff, hotel: other_hotel)

      patch operations_ticket_path(ticket),
            headers: auth_header(manager),
            params: { ticket: { staff_id: cross_hotel_staff.id } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Staff must belong to the same hotel")
      expect(ticket.reload.staff).to be_nil
    end

    it "returns 403 for admins" do
      ticket = create(:ticket, hotel: hotel, guest: guest, department: department, staff: nil)

      patch operations_ticket_path(ticket), headers: auth_header(admin), params: { ticket: { status: "done" } }

      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for staff" do
      ticket = create(:ticket, hotel: hotel, guest: guest, department: department, staff: nil)

      patch operations_ticket_path(ticket), headers: auth_header(staff_user), params: { ticket: { status: "done" } }

      expect(response).to have_http_status(:forbidden)
    end

    it "does not change disallowed attributes" do
      ticket = create(:ticket, hotel: hotel, guest: guest, department: department, staff: nil)
      replacement_guest = create(:guest, hotel: hotel)
      replacement_department = create(:department, hotel: hotel)

      patch operations_ticket_path(ticket),
            headers: auth_header(manager),
            params: {
              ticket: {
                staff_id: staff_user.id,
                guest_id: replacement_guest.id,
                hotel_id: other_hotel.id,
                department_id: replacement_department.id,
                subject: "Changed",
                body: "Changed",
                priority: "high"
              }
            }

      expect(response).to redirect_to(operations_ticket_path(ticket))
      ticket.reload
      expect(ticket.staff).to eq(staff_user)
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
