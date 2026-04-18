module Operations
  module Tickets
    class StartService < BaseService
      option :staff
      option :ticket

      def call
        failure_result = precondition_failure

        return failure_result if failure_result

        ticket.status = :in_progress

        persist_ticket
      end

      private

      def precondition_failure
        return failure_for(:forbidden, "Actor must have staff role") unless staff.staff?
        return failure_for(:forbidden, "Ticket must belong to the same hotel") unless same_hotel?
        return failure_for(:forbidden, "Ticket must be assigned to staff") unless personally_assigned?

        failure_for(:validation_failed, "Ticket cannot be started") unless ticket.new?
      end

      def persist_ticket
        if ticket.save
          success(result: ticket)
        else
          failure(error_code: :validation_failed, messages: ticket.errors.full_messages, result: ticket)
        end
      end

      def same_hotel?
        ticket.hotel_id == staff.hotel_id
      end

      def personally_assigned?
        ticket.staff_id == staff.id
      end

      def failure_for(error_code, message)
        failure(error_code: error_code, messages: [message], result: ticket)
      end
    end
  end
end
