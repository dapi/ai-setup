require "rails_helper"

RSpec.describe "Admin access" do
  let!(:hotel) { create(:hotel, name: "Aurora") }
  let!(:staff_member) { create(:staff, :admin, hotel: hotel) }
  let!(:department) { Department.create!(hotel: hotel, name: "Housekeeping") }
  let!(:guest) do
    Guest.create!(
      hotel: hotel,
      room_number: "101",
      name: "John Guest",
      identifier_token: "guest-token-101"
    )
  end
  let!(:ticket) do
    Ticket.create!(
      guest: guest,
      department: department,
      staff: staff_member,
      status: :in_progress,
      priority: :high
    )
  end

  describe "GET /admin" do
    it "returns unauthorized without credentials" do
      get admin_root_path

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns the hotels page with valid credentials" do
      get admin_root_path, headers: authorization_header

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Hotels", hotel.name)
    end
  end

  describe "GET /admin/staff" do
    it "returns the staff list with valid credentials" do
      get admin_staff_index_path, headers: authorization_header

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(staff_member.name, staff_member.email)
    end
  end

  describe "GET /admin/tickets" do
    it "returns the tickets list with valid credentials" do
      get admin_tickets_path, headers: authorization_header

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(guest.name, department.name, ticket.status, ticket.priority)
    end
  end

  def authorization_header
    encoded = Base64.strict_encode64("#{staff_member.email}:password")
    { "Authorization" => "Basic #{encoded}" }
  end
end
