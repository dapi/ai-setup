require 'rails_helper'

RSpec.describe "Users::Registrations", type: :request do
  describe "POST /users" do
    let(:valid_params) do
      { user: { email: "test@example.com", password: "password123", password_confirmation: "password123" } }
    end

    context "with valid params" do
      it "creates a user with unconfirmed email" do
        expect {
          post "/users", params: valid_params
        }.to change(User, :count).by(1)

        user = User.last
        expect(user.confirmed_at).to be_nil
      end

      it "redirects to registration page with success notice" do
        post "/users", params: valid_params
        expect(response).to redirect_to(new_user_registration_path)
        follow_redirect!
        expect(response).to be_successful
      end

      it "enqueues a confirmation email" do
        expect {
          post "/users", params: valid_params
        }.to have_enqueued_mail(Devise::Mailer, :confirmation_instructions)
      end
    end

    context "with invalid email" do
      it "does not create a user" do
        expect {
          post "/users", params: { user: { email: "invalid", password: "password123", password_confirmation: "password123" } }
        }.not_to change(User, :count)
      end
    end

    context "with duplicate email" do
      let!(:existing_user) { create(:user, :confirmed, email: "test@example.com") }

      it "does not create a user" do
        expect {
          post "/users", params: valid_params
        }.not_to change(User, :count)
      end
    end

    context "with password too short" do
      it "does not create a user" do
        expect {
          post "/users", params: { user: { email: "test@example.com", password: "short", password_confirmation: "short" } }
        }.not_to change(User, :count)
      end
    end

    context "with mismatched passwords" do
      it "does not create a user" do
        expect {
          post "/users", params: { user: { email: "test@example.com", password: "password123", password_confirmation: "different123" } }
        }.not_to change(User, :count)
      end
    end
  end
end
