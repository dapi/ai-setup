module Admin
  module Hotels
    class DestroyService < BaseService
      option :hotel

      def call
        hotel.destroy!

        success(result: hotel)
      rescue ActiveRecord::DeleteRestrictionError
        failure(
          error_code: :associated_records_exist,
          messages: [I18n.t("admin.hotels.destroy.associated_records_exist")],
          result: hotel
        )
      end
    end
  end
end
