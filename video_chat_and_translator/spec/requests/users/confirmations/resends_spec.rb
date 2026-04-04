require 'rails_helper'

RSpec.describe "Users::Confirmations::Resends", type: :request do
  describe "POST /users/confirmations/resend" do
    let!(:unconfirmed_user) { create(:user, :unconfirmed, email: "unconfirmed@example.com") }
    let!(:confirmed_user) { create(:user, :confirmed, email: "confirmed@example.com") }

    context "with email of unconfirmed user" do
      it "resends confirmation and redirects with notice" do
        expect {
          post "/users/confirmations/resend", params: { email: "unconfirmed@example.com" }
        }.to have_enqueued_mail(Devise::Mailer, :confirmation_instructions)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "with email of confirmed user" do
      it "redirects with not found alert" do
        post "/users/confirmations/resend", params: { email: "confirmed@example.com" }
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "with non-existent email" do
      it "redirects with not found alert" do
        post "/users/confirmations/resend", params: { email: "nonexistent@example.com" }
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
