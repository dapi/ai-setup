class Users::Confirmations::ResendsController < ApplicationController
  skip_before_action :authenticate_user!

  def create
    user = User.find_by(email: params[:email])

    if user && !user.confirmed?
      user.resend_confirmation_instructions
      redirect_to new_user_session_path,
                  notice: I18n.t("auth.confirmation.resend_success")
    else
      redirect_to new_user_session_path,
                  alert: I18n.t("auth.confirmation.resend_not_found")
    end
  end
end
