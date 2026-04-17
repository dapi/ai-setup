require "rails_helper"

RSpec.describe "Admin hotel tickets" do
  let!(:hotel) { create(:hotel, name: "Grand Palace", slug: "grand-palace-slug") }
  let!(:other_hotel) { create(:hotel, name: "Aurora", slug: "aurora-slug") }
  let!(:admin) { create(:staff, :admin, hotel: hotel) }

  describe "GET /admin/hotels/:hotel_slug/tickets" do
    it "returns 401 when not authenticated" do
      get admin_hotel_tickets_path(hotel)

      expect(response).to have_http_status(:unauthorized)
    end

    it "renders hotel tickets for admin role" do
      guest = create(:guest, hotel: hotel, name: "Alice Guest")
      department = create(:department, hotel: hotel, name: "Housekeeping")
      assigned_staff = create(:staff, hotel: hotel, name: "Assigned Staff")
      create(
        :ticket,
        hotel: hotel,
        guest: guest,
        department: department,
        staff: assigned_staff,
        subject: "Extra towels",
        body: "Please bring extra towels."
      )

      other_guest = create(:guest, hotel: other_hotel, name: "Bob Guest")
      other_department = create(:department, hotel: other_hotel, name: "Concierge")
      create(
        :ticket,
        hotel: other_hotel,
        guest: other_guest,
        department: other_department,
        staff: nil,
        subject: "Taxi booking",
        body: "Please book a taxi."
      )

      get admin_hotel_tickets_path(hotel), headers: auth_header(admin)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(
        "Extra towels",
        "Please bring extra towels.",
        "Alice Guest",
        "Housekeeping",
        "Assigned Staff"
      )
      expect(response.body).not_to include("Taxi booking")
    end

    it "renders unassigned text for tickets without staff" do
      guest = create(:guest, hotel: hotel)
      department = create(:department, hotel: hotel)
      create(:ticket, hotel: hotel, guest: guest, department: department, staff: nil)

      get admin_hotel_tickets_path(hotel), headers: auth_header(admin)

      expect(response.body).to include("Unassigned")
    end

    it "does not render tickets with cross-hotel associations" do
      guest = create(:guest, hotel: hotel, name: "Alice Guest")
      department = create(:department, hotel: hotel, name: "Housekeeping")
      other_staff = create(:staff, hotel: other_hotel, name: "Bob Other")
      ticket = create(:ticket, hotel: hotel, guest: guest, department: department, staff: nil, subject: "Broken record")

      # Simulate invalid historical data that bypassed model validations.
      ticket.update_columns(staff_id: other_staff.id)

      get admin_hotel_tickets_path(hotel), headers: auth_header(admin)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Broken record", "Bob Other")
    end

    it "renders the empty state when hotel tickets are empty" do
      empty_hotel = create(:hotel, name: "Empty Hotel", slug: "empty-hotel-slug")
      guest_admin_hotel = create(:hotel, name: "Admin Hotel", slug: "admin-hotel-slug")
      guest_admin = create(:staff, :admin, hotel: guest_admin_hotel)

      get admin_hotel_tickets_path(empty_hotel), headers: auth_header(guest_admin)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("No tickets for this hotel.")
    end

    it "redirects manager to root" do
      manager = create(:staff, :manager, hotel: hotel)

      get admin_hotel_tickets_path(hotel), headers: auth_header(manager)

      expect(response).to redirect_to(root_path)
    end

    it "redirects staff to root" do
      staff_member = create(:staff, hotel: hotel)

      get admin_hotel_tickets_path(hotel), headers: auth_header(staff_member)

      expect(response).to redirect_to(root_path)
    end

    it "returns 404 when the hotel is not found" do
      get admin_hotel_tickets_path("missing-slug"), headers: auth_header(admin)

      expect(response).to have_http_status(:not_found)
      expect(response.body).to eq("Not Found")
    end
  end
end
