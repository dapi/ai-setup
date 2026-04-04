require 'rails_helper'

RSpec.describe "Users::Confirmations", type: :request do
  describe "GET /users/confirmation" do
    context "with valid token" do
      let!(:user) { create(:user, :unconfirmed) }

      before do
        user.send_confirmation_instructions
        user.reload
      end

      it "confirms the user and redirects to login" do
        get "/users/confirmation", params: { confirmation_token: user.confirmation_token }
        expect(response).to redirect_to(new_user_session_path)
        expect(user.reload.confirmed_at).not_to be_nil
      end
    end

    context "with expired token" do
      let!(:user) { create(:user, :expired_confirmation) }

      before do
        user.update_column(:confirmation_token, "expiredtoken123")
      end

      it "redirects to login with invalid token alert" do
        get "/users/confirmation", params: { confirmation_token: "expiredtoken123" }
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "with already used token" do
      let!(:user) { create(:user, :confirmed) }

      it "redirects to login with invalid token alert" do
        get "/users/confirmation", params: { confirmation_token: "invalidtoken" }
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
