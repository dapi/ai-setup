module ConfirmableLoginHandler
  extend ActiveSupport::Concern

  private

  def handle_unconfirmed_user(user)
    return unless user && !user.confirmed?

    if user.confirmation_token_expired?
      user.resend_confirmation_instructions
      redirect_to new_user_session_path,
                  alert: I18n.t("auth.login.confirmation_resent")
    else
      redirect_to new_user_session_path,
                  alert: I18n.t("auth.login.unconfirmed")
    end
  end
end
