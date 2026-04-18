# rubocop:disable Metrics/BlockLength
require "rails_helper"

RSpec.describe "Operations staff ticket workflow" do
  it "creates staff, assigns a ticket, and completes the workflow without admin credentials" do
    hotel = create(:hotel)
    other_hotel = create(:hotel)
    manager = create(:staff, :manager, hotel: hotel)
    other_manager = create(:staff, :manager, hotel: other_hotel)
    department = create(:department, hotel: hotel)
    other_department = create(:department, hotel: other_hotel)
    guest = create(:guest, hotel: hotel)
    ticket = create(:ticket, hotel: hotel, guest: guest, department: department, staff: nil, status: :new)

    post operations_staff_index_path,
         headers: auth_header(manager),
         params: {
           staff: {
             name: "Workflow Staff",
             email: "workflow.staff@example.com",
             password: "password",
             password_confirmation: "password",
             department_id: department.id
           }
         }

    expect(response).to redirect_to(operations_staff_index_path)
    created_staff = Staff.find_by!(email: "workflow.staff@example.com")

    patch operations_ticket_path(ticket),
          headers: auth_header(manager),
          params: { ticket: { staff_id: created_staff.id } }

    expect(response).to redirect_to(operations_ticket_path(ticket))
    expect(ticket.reload.staff).to eq(created_staff)

    get operations_tickets_path, headers: auth_header(created_staff)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(operations_ticket_path(ticket))

    patch start_operations_ticket_path(ticket), headers: auth_header(created_staff)

    expect(response).to redirect_to(operations_ticket_path(ticket))
    expect(ticket.reload.status).to eq("in_progress")

    patch complete_operations_ticket_path(ticket), headers: auth_header(created_staff)

    expect(response).to redirect_to(operations_ticket_path(ticket))
    expect(ticket.reload.status).to eq("done")

    get operations_ticket_path(ticket), headers: auth_header(other_manager)

    expect(response).to have_http_status(:not_found)

    other_staff = create(:staff, hotel: other_hotel, department: other_department)
    get operations_ticket_path(ticket), headers: auth_header(other_staff)

    expect(response).to have_http_status(:not_found)
  end
end
# rubocop:enable Metrics/BlockLength
