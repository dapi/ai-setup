module Admin
  class BaseController < ApplicationController
    before_action :authenticate_staff!
    layout "admin"

    private

    def authenticate_staff!
      header = request.headers["Authorization"]

      unless header&.start_with?("Basic ")
        return http_401
      end

      decoded = Base64.strict_decode64(header.delete_prefix("Basic "))
      email, password = decoded.split(":", 2)
      @current_staff = Staff.find_by(email: email)&.authenticate(password)

      http_401 unless @current_staff
    rescue ArgumentError
      http_401
    end

    def http_401
      response.headers["WWW-Authenticate"] = 'Basic realm="Admin"'
      render plain: "Unauthorized", status: :unauthorized
    end
  end
end
