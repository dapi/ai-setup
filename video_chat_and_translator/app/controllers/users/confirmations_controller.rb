class Users::ConfirmationsController < Devise::ConfirmationsController
  skip_before_action :authenticate_user!

  def show
    self.resource = resource_class.confirm_by_token(params[:confirmation_token])

    if resource.errors.empty?
      redirect_to new_user_session_path,
                  notice: I18n.t("auth.confirmation.confirmed")
    else
      redirect_to new_user_session_path,
                  alert: I18n.t("auth.confirmation.invalid_token")
    end
  end
end
