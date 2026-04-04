class Users::SessionsController < Devise::SessionsController
  include ConfirmableLoginHandler

  skip_before_action :authenticate_user!

  def new
    render inertia: "auth/Login", props: {
      translations: I18n.t("auth.login")
    }
  end

  def create
    caught = catch(:warden) do
      self.resource = warden.authenticate(auth_options)
      nil
    end

    if resource
      sign_in(resource_name, resource)
      redirect_to authenticated_root_path, notice: I18n.t("devise.sessions.signed_in")
    elsif caught && caught[:message] == :unconfirmed
      user = User.find_by(email: params.dig(:user, :email))
      handle_unconfirmed_user(user)
    else
      redirect_to new_user_session_path, alert: I18n.t("auth.login.invalid_credentials")
    end
  end

  def destroy
    Devise.sign_out_all_scopes ? sign_out : sign_out(resource_name)
    redirect_to new_user_session_path
  end
end
