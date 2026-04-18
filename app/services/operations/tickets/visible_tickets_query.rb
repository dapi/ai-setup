module Operations
  module Tickets
    class VisibleTicketsQuery < BaseService
      option :staff

      def call
        return Ticket.none if staff.admin?
        return base_scope if staff.manager?

        base_scope.where(staff_id: staff.id)
                  .or(base_scope.where(department_id: staff.department_id))
      end

      private

      def base_scope
        staff.hotel.tickets
             .preload(:department, :staff)
             .order(created_at: :desc, id: :desc)
      end
    end
  end
end
