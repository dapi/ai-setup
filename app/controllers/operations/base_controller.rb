module Operations
  class BaseController < ApplicationController
    before_action :authenticate_staff!
    rescue_from ActiveRecord::RecordNotFound, with: :not_found
    layout "operations"

    helper_method :current_staff
    attr_reader :current_staff

    private

    def authenticate_staff!
      credentials = credentials_from_header

      return http_unauthorized unless credentials

      @current_staff = authenticated_staff(*credentials)

      return http_unauthorized unless current_staff

      forbidden if current_staff.admin?
    rescue ArgumentError
      http_unauthorized
    end

    def credentials_from_header
      header = request.headers["Authorization"]

      return unless header&.start_with?("Basic ")

      credentials = Base64.strict_decode64(header.delete_prefix("Basic ")).split(":", 2)

      credentials if credentials.all?(&:present?)
    end

    def authenticated_staff(email, password)
      ::Staff.find_by(email: email)&.authenticate(password)
    end

    def require_manager!
      forbidden unless @current_staff.manager?
    end

    def require_staff!
      forbidden unless @current_staff.staff?
    end

    def http_unauthorized
      response.headers["WWW-Authenticate"] = 'Basic realm="Operations"'
      render plain: "Unauthorized", status: :unauthorized
    end

    def forbidden
      render plain: "Forbidden", status: :forbidden
    end

    def not_found
      render plain: "Not Found", status: :not_found
    end

    def current_hotel
      @current_staff.hotel
    end
  end
end
