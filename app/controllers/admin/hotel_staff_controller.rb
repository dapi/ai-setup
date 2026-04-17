module Admin
  class HotelStaffController < BaseController
    before_action :set_hotel

    def index
      @staff = @hotel.staff.order(:name).page(params[:page])
    end

    def show
      @staff_member = @hotel.staff.find(params[:id])
    end

    private

    def set_hotel
      @hotel = find_hotel_by_slug!(:hotel_slug)
    end
  end
end
