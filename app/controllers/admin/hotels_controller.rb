module Admin
  class HotelsController < BaseController
    before_action :require_hotel_access!

    def index
      @hotels = Hotel.order(:name)
    end

    private

    def require_hotel_access!
      return if @current_staff.admin? || @current_staff.manager?

      render plain: "Forbidden", status: :forbidden
    end
  end
end
