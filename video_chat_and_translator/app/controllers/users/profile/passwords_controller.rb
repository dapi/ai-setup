# frozen_string_literal: true

module Users
  module Profile
    class PasswordsController < ApplicationController
      def update
        if current_user.update_with_password(password_params)
          bypass_sign_in(current_user)
          redirect_to users_profile_path, notice: I18n.t("auth.profile.password.success")
        else
          render inertia: "profile/Show", props: {
            translations: I18n.t("auth.profile"),
            errors: current_user.errors.messages
          }
        end
      end

      private

      def password_params
        params.require(:user).permit(:current_password, :password, :password_confirmation)
      end
    end
  end
end
