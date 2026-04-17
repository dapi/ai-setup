module Admin
  module Hotels
    class TicketsQuery < BaseService
      option :hotel

      def call
        hotel.tickets
             .left_outer_joins(:staff)
             .where("staffs.hotel_id = :hotel_id OR tickets.staff_id IS NULL", hotel_id: hotel.id)
             .preload(:guest, :department, :staff)
             .order(created_at: :desc)
      end
    end
  end
end
