require 'rails_helper'

RSpec.describe "Users::Profile::Passwords", type: :request do
  let!(:confirmed_user) { create(:user, :confirmed, email: "user@example.com", password: "password123") }

  describe "PATCH /users/profile/password" do
    context "when authenticated" do
      before { sign_in confirmed_user }

      context "with correct current password and valid new password" do
        it "updates the password, keeps the session, and redirects with notice" do
          patch "/users/profile/password", params: {
            user: {
              current_password: "password123",
              password: "newpassword123",
              password_confirmation: "newpassword123"
            }
          }

          expect(response).to redirect_to(users_profile_path)
          follow_redirect!
          expect(response).to be_successful

          confirmed_user.reload
          expect(confirmed_user.valid_password?("newpassword123")).to be true
        end
      end

      context "with incorrect current password" do
        it "renders the profile page with an error on current_password" do
          patch "/users/profile/password", params: {
            user: {
              current_password: "wrongpassword",
              password: "newpassword123",
              password_confirmation: "newpassword123"
            }
          }

          expect(response).to be_successful
          confirmed_user.reload
          expect(confirmed_user.valid_password?("password123")).to be true
        end
      end

      context "with new password shorter than 8 characters" do
        it "renders the profile page with a password length error" do
          patch "/users/profile/password", params: {
            user: {
              current_password: "password123",
              password: "short",
              password_confirmation: "short"
            }
          }

          expect(response).to be_successful
          confirmed_user.reload
          expect(confirmed_user.valid_password?("password123")).to be true
        end
      end

      context "when new password and confirmation do not match" do
        it "renders the profile page with a confirmation error" do
          patch "/users/profile/password", params: {
            user: {
              current_password: "password123",
              password: "newpassword123",
              password_confirmation: "different123"
            }
          }

          expect(response).to be_successful
          confirmed_user.reload
          expect(confirmed_user.valid_password?("password123")).to be true
        end
      end

      context "with empty current password" do
        it "renders the profile page with validation errors" do
          patch "/users/profile/password", params: {
            user: {
              current_password: "",
              password: "newpassword123",
              password_confirmation: "newpassword123"
            }
          }

          expect(response).to be_successful
          confirmed_user.reload
          expect(confirmed_user.valid_password?("password123")).to be true
        end
      end
    end

    context "when not authenticated" do
      it "redirects to login" do
        patch "/users/profile/password", params: {
          user: {
            current_password: "password123",
            password: "newpassword123",
            password_confirmation: "newpassword123"
          }
        }
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
