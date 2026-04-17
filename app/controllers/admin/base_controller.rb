module Admin
  class BaseController < ApplicationController
    before_action :authenticate_staff!
    before_action :require_admin!
    rescue_from ActiveRecord::RecordNotFound, with: :not_found
    layout "admin"

    private

    def authenticate_staff!
      header = request.headers["Authorization"]

      return http_unauthorized unless header&.start_with?("Basic ")

      decoded = Base64.strict_decode64(header.delete_prefix("Basic "))
      email, password = decoded.split(":", 2)
      @current_staff = Staff.find_by(email: email)&.authenticate(password)

      http_unauthorized unless @current_staff
    rescue ArgumentError
      http_unauthorized
    end

    def http_unauthorized
      response.headers["WWW-Authenticate"] = 'Basic realm="Admin"'
      render plain: "Unauthorized", status: :unauthorized
    end

    def require_admin!
      redirect_to root_path unless @current_staff.admin?
    end

    def find_hotel_by_slug!(param_name)
      Hotel.find_by!(slug: params[param_name])
    end

    def not_found
      render plain: "Not Found", status: :not_found
    end
  end
end
