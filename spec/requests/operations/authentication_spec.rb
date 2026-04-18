require "rails_helper"

RSpec.describe "Operations authentication" do
  let(:hotel) { create(:hotel) }
  let(:manager) { create(:staff, :manager, hotel: hotel) }

  describe "GET /operations" do
    it "returns 401 without credentials" do
      get operations_root_path

      expect(response).to have_http_status(:unauthorized)
      expect(response.headers["WWW-Authenticate"]).to eq('Basic realm="Operations"')
    end

    it "returns 401 with invalid credentials" do
      get operations_root_path, headers: invalid_auth_header(manager.email)

      expect(response).to have_http_status(:unauthorized)
      expect(response.headers["WWW-Authenticate"]).to eq('Basic realm="Operations"')
    end

    it "returns 401 with malformed Basic credentials" do
      get operations_root_path, headers: { "Authorization" => "Basic malformed" }

      expect(response).to have_http_status(:unauthorized)
      expect(response.headers["WWW-Authenticate"]).to eq('Basic realm="Operations"')
    end
  end

  def invalid_auth_header(email)
    encoded = Base64.strict_encode64("#{email}:wrong-password")
    { "Authorization" => "Basic #{encoded}" }
  end
end
