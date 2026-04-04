class Users::RegistrationsController < Devise::RegistrationsController
  skip_before_action :authenticate_user!

  def new
    render inertia: "auth/Register", props: {
      translations: I18n.t("auth.register")
    }
  end

  def create
    build_resource(sign_up_params)

    if resource.save
      redirect_to new_user_registration_path,
                  notice: I18n.t("auth.register.success")
    else
      render inertia: "auth/Register", props: {
        translations: I18n.t("auth.register"),
        errors: resource.errors.messages
      }
    end
  end

  private

  def sign_up_params
    params.require(:user).permit(:email, :password, :password_confirmation)
  end
end
