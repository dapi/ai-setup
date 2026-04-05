# frozen_string_literal: true

module Users
  module Profile
    class EmailsController < ApplicationController
      def update
        if current_user.email == email_params[:email]
          return render inertia: "profile/Show", props: {
            translations: I18n.t("auth.profile"),
            errors: { email: [ I18n.t("auth.profile.email.same_as_current") ] }
          }
        end

        if current_user.update(email: email_params[:email])
          redirect_to users_profile_path, notice: I18n.t("auth.profile.email.success")
        else
          render inertia: "profile/Show", props: {
            translations: I18n.t("auth.profile"),
            errors: current_user.errors.messages
          }
        end
      end

      private

      def email_params
        params.require(:user).permit(:email)
      end
    end
  end
end
