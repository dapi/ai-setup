require 'rails_helper'

RSpec.describe "Users::Profile", type: :request do
  let!(:confirmed_user) { create(:user, :confirmed, email: "profile@example.com", password: "password123") }

  describe "GET /users/profile" do
    context "when authenticated" do
      before { sign_in confirmed_user }

      it "renders the profile page successfully" do
        get "/users/profile"
        expect(response).to be_successful
      end

      it "renders the profile/Show inertia component" do
        get "/users/profile"
        expect(response).to be_successful
        expect(response.body).to include("profile/Show")
      end

      context "when user has unconfirmed_email" do
        before do
          confirmed_user.update_columns(unconfirmed_email: "newemail@example.com")
        end

        it "includes unconfirmed_email in current_user shared props" do
          get "/users/profile"
          expect(response).to be_successful
          expect(response.body).to include("newemail@example.com")
        end
      end
    end

    context "when not authenticated" do
      it "redirects to login" do
        get "/users/profile"
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
