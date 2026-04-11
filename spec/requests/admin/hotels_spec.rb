require "rails_helper"

RSpec.describe "GET /admin/hotels" do
  let!(:hotel) { create(:hotel, name: "Grand Palace") }

  describe "authentication" do
    it "returns 401 with WWW-Authenticate when no Authorization header" do
      get admin_hotels_path

      expect(response).to have_http_status(:unauthorized)
      expect(response.headers["WWW-Authenticate"]).to eq('Basic realm="Admin"')
    end

    it "returns 401 with WWW-Authenticate for Bearer token" do
      get admin_hotels_path, headers: { "Authorization" => "Bearer sometoken" }

      expect(response).to have_http_status(:unauthorized)
      expect(response.headers["WWW-Authenticate"]).to eq('Basic realm="Admin"')
    end

    it "returns 401 with WWW-Authenticate for invalid base64" do
      get admin_hotels_path, headers: { "Authorization" => "Basic !!!" }

      expect(response).to have_http_status(:unauthorized)
      expect(response.headers["WWW-Authenticate"]).to eq('Basic realm="Admin"')
    end

    it "returns 401 when email not found in DB" do
      encoded = Base64.strict_encode64("unknown@example.com:password")
      get admin_hotels_path, headers: { "Authorization" => "Basic #{encoded}" }

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 401 when password is wrong" do
      staff = create(:staff, :admin, hotel: hotel)
      encoded = Base64.strict_encode64("#{staff.email}:wrongpassword")
      get admin_hotels_path, headers: { "Authorization" => "Basic #{encoded}" }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "authorization" do
    it "returns 200 with hotel name for admin role" do
      admin = create(:staff, :admin, hotel: hotel)
      get admin_hotels_path, headers: auth_header(admin)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(hotel.name)
    end

    it "returns 200 with hotel name for manager role" do
      manager = create(:staff, :manager, hotel: hotel)
      get admin_hotels_path, headers: auth_header(manager)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(hotel.name)
    end

    it "returns 403 for staff role" do
      staff = create(:staff, hotel: hotel)
      get admin_hotels_path, headers: auth_header(staff)

      expect(response).to have_http_status(:forbidden)
    end
  end

  def auth_header(staff_record)
    encoded = Base64.strict_encode64("#{staff_record.email}:password")
    { "Authorization" => "Basic #{encoded}" }
  end
end
