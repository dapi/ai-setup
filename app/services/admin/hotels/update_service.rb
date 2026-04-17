module Admin
  module Hotels
    class UpdateService < BaseService
      option :hotel
      option :params

      def call
        if hotel.update(params.to_h)
          success(result: hotel)
        else
          failure(error_code: :validation_failed, messages: hotel.errors.full_messages, result: hotel)
        end
      end
    end
  end
end
