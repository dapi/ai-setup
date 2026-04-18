require "rails_helper"

RSpec.describe "Operations access" do
  let(:hotel) { create(:hotel) }
  let(:admin) { create(:staff, :admin, hotel: hotel) }
  let(:manager) { create(:staff, :manager, hotel: hotel) }
  let(:staff_user) { create(:staff, hotel: hotel) }

  describe "GET /operations" do
    it "returns 403 for admin credentials" do
      get operations_root_path, headers: auth_header(admin)

      expect(response).to have_http_status(:forbidden)
    end

    it "redirects manager to operations tickets" do
      get operations_root_path, headers: auth_header(manager)

      expect(response).to redirect_to(operations_tickets_path)
    end

    it "redirects staff to operations tickets" do
      get operations_root_path, headers: auth_header(staff_user)

      expect(response).to redirect_to(operations_tickets_path)
    end
  end
end
