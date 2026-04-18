# rubocop:disable Metrics/BlockLength
require "rails_helper"

RSpec.describe "Operations ticket transitions" do
  let(:hotel) { create(:hotel) }
  let(:other_hotel) { create(:hotel) }
  let(:department) { create(:department, hotel: hotel) }
  let(:other_department) { create(:department, hotel: hotel) }
  let(:cross_hotel_department) { create(:department, hotel: other_hotel) }
  let(:staff_user) { create(:staff, hotel: hotel, department: department) }
  let(:manager) { create(:staff, :manager, hotel: hotel) }
  let(:admin) { create(:staff, :admin, hotel: hotel) }
  let(:guest) { create(:guest, hotel: hotel) }
  let(:other_guest) { create(:guest, hotel: other_hotel) }

  it "starts an assigned new ticket" do
    ticket = create(:ticket, hotel: hotel, guest: guest, department: department, staff: staff_user, status: :new)

    patch start_operations_ticket_path(ticket), headers: auth_header(staff_user)

    expect(response).to redirect_to(operations_ticket_path(ticket))
    expect(flash[:notice]).to eq("Ticket updated")
    expect(ticket.reload.status).to eq("in_progress")
  end

  it "completes an assigned in-progress ticket" do
    ticket = create(
      :ticket,
      hotel: hotel,
      guest: guest,
      department: department,
      staff: staff_user,
      status: :in_progress
    )

    patch complete_operations_ticket_path(ticket), headers: auth_header(staff_user)

    expect(response).to redirect_to(operations_ticket_path(ticket))
    expect(flash[:notice]).to eq("Ticket updated")
    expect(ticket.reload.status).to eq("done")
  end

  it "returns 422 for direct complete from new" do
    ticket = create(:ticket, hotel: hotel, guest: guest, department: department, staff: staff_user, status: :new)

    patch complete_operations_ticket_path(ticket), headers: auth_header(staff_user)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("Ticket cannot be completed")
    expect(ticket.reload.status).to eq("new")
  end

  it "returns 422 when starting done or canceled tickets" do
    done_ticket = create(:ticket, hotel: hotel, guest: guest, department: department, staff: staff_user, status: :done)
    canceled_ticket = create(
      :ticket,
      hotel: hotel,
      guest: guest,
      department: department,
      staff: staff_user,
      status: :canceled
    )

    patch start_operations_ticket_path(done_ticket), headers: auth_header(staff_user)
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("Ticket cannot be started")
    expect(done_ticket.reload.status).to eq("done")

    patch start_operations_ticket_path(canceled_ticket), headers: auth_header(staff_user)
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("Ticket cannot be started")
    expect(canceled_ticket.reload.status).to eq("canceled")
  end

  it "returns 422 for same-department unassigned tickets" do
    ticket = create(:ticket, hotel: hotel, guest: guest, department: department, staff: nil, status: :new)

    patch start_operations_ticket_path(ticket), headers: auth_header(staff_user)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("Ticket must be assigned to staff")
    expect(ticket.reload.status).to eq("new")
  end

  it "returns 404 for unrelated same-hotel tickets" do
    ticket = create(:ticket, hotel: hotel, guest: guest, department: other_department, staff: nil, status: :new)

    patch start_operations_ticket_path(ticket), headers: auth_header(staff_user)

    expect(response).to have_http_status(:not_found)
    expect(ticket.reload.status).to eq("new")
  end

  it "returns 404 for cross-hotel tickets" do
    ticket = create(:ticket, hotel: other_hotel, guest: other_guest, department: cross_hotel_department, staff: nil)

    patch start_operations_ticket_path(ticket), headers: auth_header(staff_user)

    expect(response).to have_http_status(:not_found)
  end

  it "returns 403 for manager start and complete requests" do
    ticket = create(:ticket, hotel: hotel, guest: guest, department: department, staff: staff_user, status: :new)

    patch start_operations_ticket_path(ticket), headers: auth_header(manager)
    expect(response).to have_http_status(:forbidden)

    patch complete_operations_ticket_path(ticket), headers: auth_header(manager)
    expect(response).to have_http_status(:forbidden)
  end

  it "returns 403 for admin start and complete requests" do
    ticket = create(:ticket, hotel: hotel, guest: guest, department: department, staff: staff_user, status: :new)

    patch start_operations_ticket_path(ticket), headers: auth_header(admin)
    expect(response).to have_http_status(:forbidden)

    patch complete_operations_ticket_path(ticket), headers: auth_header(admin)
    expect(response).to have_http_status(:forbidden)
  end
end
# rubocop:enable Metrics/BlockLength
