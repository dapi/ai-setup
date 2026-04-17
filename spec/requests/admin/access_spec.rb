require "rails_helper"

RSpec.describe "Admin access" do
  let!(:hotel) { create(:hotel, name: "Aurora") }
  let!(:staff_member) { create(:staff, :admin, hotel: hotel) }
  let!(:manager) { create(:staff, :manager, hotel: hotel) }
  let!(:staff_user) { create(:staff, hotel: hotel) }
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
    create(
      :ticket,
      hotel: hotel,
      staff: staff_member,
      guest: guest,
      department: department,
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

    it "redirects manager to root" do
      get admin_root_path, headers: authorization_header(manager)

      expect(response).to redirect_to(root_path)
    end

    it "redirects staff to root" do
      get admin_root_path, headers: authorization_header(staff_user)

      expect(response).to redirect_to(root_path)
    end
  end

  describe "GET /admin/staff" do
    it "returns the staff list with valid credentials" do
      get admin_staff_index_path, headers: authorization_header

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(staff_member.name, staff_member.email)
    end

    it "redirects manager to root" do
      get admin_staff_index_path, headers: authorization_header(manager)

      expect(response).to redirect_to(root_path)
    end

    it "redirects staff to root" do
      get admin_staff_index_path, headers: authorization_header(staff_user)

      expect(response).to redirect_to(root_path)
    end
  end

  describe "GET /admin/tickets" do
    it "returns the tickets list with valid credentials" do
      get admin_tickets_path, headers: authorization_header

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(guest.name, department.name, ticket.status, ticket.priority)
    end

    it "redirects manager to root" do
      get admin_tickets_path, headers: authorization_header(manager)

      expect(response).to redirect_to(root_path)
    end

    it "redirects staff to root" do
      get admin_tickets_path, headers: authorization_header(staff_user)

      expect(response).to redirect_to(root_path)
    end
  end

  def authorization_header(staff = staff_member)
    encoded = Base64.strict_encode64("#{staff.email}:password")
    { "Authorization" => "Basic #{encoded}" }
  end
end
