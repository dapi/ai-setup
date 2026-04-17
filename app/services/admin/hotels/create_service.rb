module Admin
  module Hotels
    class CreateService < BaseService
      option :params

      def call
        hotel = Hotel.new(params.to_h.merge(slug: generated_slug))

        if hotel.save
          success(result: hotel)
        else
          failure(error_code: :validation_failed, messages: hotel.errors.full_messages, result: hotel)
        end
      end

      private

      def generated_slug
        Admin::Hotels::SlugGenerator.call(name: params[:name])
      end
    end
  end
end
