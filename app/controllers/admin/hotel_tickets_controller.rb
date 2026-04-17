module Admin
  class HotelTicketsController < BaseController
    before_action :set_hotel

    def index
      @tickets = Admin::Hotels::TicketsQuery.call(hotel: @hotel).page(params[:page])
    end

    private

    def set_hotel
      @hotel = find_hotel_by_slug!(:hotel_slug)
    end
  end
end
