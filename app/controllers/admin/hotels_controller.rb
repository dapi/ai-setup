module Admin
  class HotelsController < BaseController
    before_action :set_hotel, only: %i[show edit update destroy]

    def index
      @hotels = Hotel.order(:name).page(params[:page])
    end

    def show; end

    def new
      @hotel = Hotel.new
    end

    def create
      result = Admin::Hotels::CreateService.call(params: hotel_params)
      @hotel = result.result

      if result.success?
        redirect_to admin_hotels_path, notice: t("admin.hotels.create.success")
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      result = Admin::Hotels::UpdateService.call(hotel: @hotel, params: hotel_params)
      @hotel = result.result

      if result.success?
        redirect_to admin_hotels_path, notice: t("admin.hotels.update.success")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      result = Admin::Hotels::DestroyService.call(hotel: @hotel)

      if result.success?
        redirect_to admin_hotels_path, notice: t("admin.hotels.destroy.success")
      else
        redirect_to admin_hotels_path, alert: result.messages.to_sentence
      end
    end

    private

    def set_hotel
      @hotel = find_hotel_by_slug!(:slug)
    end

    def hotel_params
      params.require(:hotel).permit(:name, :timezone)
    end
  end
end
