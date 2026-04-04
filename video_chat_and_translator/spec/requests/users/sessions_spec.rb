require 'rails_helper'

RSpec.describe "Users::Sessions", type: :request do
  let!(:confirmed_user) { create(:user, :confirmed, email: "confirmed@example.com", password: "password123") }
  let!(:unconfirmed_user) { create(:user, :unconfirmed, email: "unconfirmed@example.com", password: "password123") }
  let!(:expired_user) { create(:user, :expired_confirmation, email: "expired@example.com", password: "password123") }

  describe "POST /users/sign_in" do
    context "with valid confirmed user" do
      it "signs in and redirects to root" do
        post "/users/sign_in", params: { user: { email: "confirmed@example.com", password: "password123" } }
        expect(response).to redirect_to(authenticated_root_path)
      end
    end

    context "with wrong email" do
      it "redirects back to login with alert" do
        post "/users/sign_in", params: { user: { email: "wrong@example.com", password: "password123" } }
        expect(response).to redirect_to(new_user_session_path)
        follow_redirect!
        expect(response).to be_successful
      end
    end

    context "with wrong password" do
      it "redirects back to login with alert" do
        post "/users/sign_in", params: { user: { email: "confirmed@example.com", password: "wrongpassword" } }
        expect(response).to redirect_to(new_user_session_path)
        follow_redirect!
        expect(response).to be_successful
      end
    end

    context "with unconfirmed email and valid token" do
      it "redirects to login with unconfirmed alert" do
        post "/users/sign_in", params: { user: { email: "unconfirmed@example.com", password: "password123" } }
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "with unconfirmed email and expired token" do
      it "resends confirmation and redirects with notice" do
        expect {
          post "/users/sign_in", params: { user: { email: "expired@example.com", password: "password123" } }
        }.to have_enqueued_mail(Devise::Mailer, :confirmation_instructions)
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "DELETE /users/sign_out" do
    it "signs out and redirects to login" do
      sign_in confirmed_user
      delete "/users/sign_out"
      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
