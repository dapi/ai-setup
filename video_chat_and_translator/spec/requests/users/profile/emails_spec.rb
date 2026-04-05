require 'rails_helper'

RSpec.describe "Users::Profile::Emails", type: :request do
  include ActiveJob::TestHelper

  let!(:confirmed_user) { create(:user, :confirmed, email: "user@example.com", password: "password123") }
  let!(:other_user) { create(:user, :confirmed, email: "taken@example.com", password: "password123") }

  describe "PATCH /users/profile/email" do
    context "when authenticated" do
      before { sign_in confirmed_user }

      context "with a valid new email" do
        it "sets unconfirmed_email, enqueues confirmation email, and redirects with notice" do
          expect {
            patch "/users/profile/email", params: { user: { email: "newemail@example.com" } }
          }.to have_enqueued_mail(Devise::Mailer, :confirmation_instructions)

          expect(response).to redirect_to(users_profile_path)
          follow_redirect!
          expect(response).to be_successful

          confirmed_user.reload
          expect(confirmed_user.unconfirmed_email).to eq("newemail@example.com")
          expect(confirmed_user.email).to eq("user@example.com")
        end
      end

      context "with the same email as current" do
        it "renders the profile page with an error" do
          patch "/users/profile/email", params: { user: { email: "user@example.com" } }
          expect(response).to be_successful
          expect(response.body).to include("совпадает с текущим email")
        end
      end

      context "with an invalid email format" do
        it "renders the profile page with validation errors" do
          patch "/users/profile/email", params: { user: { email: "not-an-email" } }
          expect(response).to be_successful
          confirmed_user.reload
          expect(confirmed_user.unconfirmed_email).to be_nil
        end
      end

      context "with an empty email" do
        it "renders the profile page with validation errors" do
          patch "/users/profile/email", params: { user: { email: "" } }
          expect(response).to be_successful
          confirmed_user.reload
          expect(confirmed_user.unconfirmed_email).to be_nil
        end
      end

      context "with an email already taken by another user" do
        it "renders the profile page with validation errors" do
          patch "/users/profile/email", params: { user: { email: "taken@example.com" } }
          expect(response).to be_successful
          confirmed_user.reload
          expect(confirmed_user.unconfirmed_email).to be_nil
        end
      end
    end

    context "when not authenticated" do
      it "redirects to login" do
        patch "/users/profile/email", params: { user: { email: "newemail@example.com" } }
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
