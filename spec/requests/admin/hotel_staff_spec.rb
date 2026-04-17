require "rails_helper"

RSpec.describe "Admin hotel staff" do
  let!(:hotel) { create(:hotel, name: "Grand Palace", slug: "grand-palace-slug") }
  let!(:other_hotel) { create(:hotel, name: "Aurora", slug: "aurora-slug") }
  let!(:admin) { create(:staff, :admin, hotel: hotel) }

  describe "GET /admin/hotels/:hotel_slug/staff" do
    it "returns 401 when not authenticated" do
      get admin_hotel_staff_index_path(hotel)

      expect(response).to have_http_status(:unauthorized)
    end

    it "renders hotel staff for admin role" do
      create(:staff, :manager, hotel: hotel, name: "Alice Manager")
      create(:staff, hotel: other_hotel, name: "Bob Other")

      get admin_hotel_staff_index_path(hotel), headers: auth_header(admin)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Alice Manager")
      expect(response.body).not_to include("Bob Other")
    end

    it "renders the empty state when hotel staff is empty" do
      hotel_without_staff = create(:hotel, name: "Empty Hotel", slug: "empty-hotel-slug")
      guest_admin_hotel = create(:hotel, name: "Admin Hotel", slug: "admin-hotel-slug")
      guest_admin = create(:staff, :admin, hotel: guest_admin_hotel)

      get admin_hotel_staff_index_path(hotel_without_staff), headers: auth_header(guest_admin)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("No staff members for this hotel.")
    end

    it "redirects manager to root" do
      manager = create(:staff, :manager, hotel: hotel)

      get admin_hotel_staff_index_path(hotel), headers: auth_header(manager)

      expect(response).to redirect_to(root_path)
    end

    it "redirects staff to root" do
      staff_member = create(:staff, hotel: hotel)

      get admin_hotel_staff_index_path(hotel), headers: auth_header(staff_member)

      expect(response).to redirect_to(root_path)
    end

    it "returns 404 when the hotel is not found" do
      get admin_hotel_staff_index_path("missing-slug"), headers: auth_header(admin)

      expect(response).to have_http_status(:not_found)
      expect(response.body).to eq("Not Found")
    end
  end

  describe "GET /admin/hotels/:hotel_slug/staff/:id" do
    it "returns 401 when not authenticated" do
      staff_member = create(:staff, :manager, hotel: hotel)

      get admin_hotel_staff_path(hotel, staff_member)

      expect(response).to have_http_status(:unauthorized)
    end

    it "renders hotel staff details for admin role" do
      staff_member = create(:staff, :manager, hotel: hotel, name: "Alice Manager")

      get admin_hotel_staff_path(hotel, staff_member), headers: auth_header(admin)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Alice Manager", staff_member.email, staff_member.role, hotel.name)
    end

    it "returns 404 for a staff member from another hotel" do
      other_staff_member = create(:staff, hotel: other_hotel)

      get admin_hotel_staff_path(hotel, other_staff_member), headers: auth_header(admin)

      expect(response).to have_http_status(:not_found)
      expect(response.body).to eq("Not Found")
    end

    it "redirects manager to root" do
      manager = create(:staff, :manager, hotel: hotel)

      get admin_hotel_staff_path(hotel, admin), headers: auth_header(manager)

      expect(response).to redirect_to(root_path)
    end

    it "redirects staff to root" do
      staff_member = create(:staff, hotel: hotel)

      get admin_hotel_staff_path(hotel, admin), headers: auth_header(staff_member)

      expect(response).to redirect_to(root_path)
    end

    it "returns 404 when the hotel is not found" do
      get admin_hotel_staff_path("missing-slug", admin), headers: auth_header(admin)

      expect(response).to have_http_status(:not_found)
      expect(response.body).to eq("Not Found")
    end
  end
end
