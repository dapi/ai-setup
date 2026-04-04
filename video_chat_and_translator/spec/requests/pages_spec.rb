require 'rails_helper'

RSpec.describe "Pages", type: :request do
  describe "GET /" do
    context "when not authenticated" do
      it "redirects to login page" do
        get "/"
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when authenticated with confirmed user" do
      let!(:user) { create(:user, :confirmed) }

      it "returns success" do
        sign_in user
        get "/"
        expect(response).to be_successful
      end
    end
  end
end
