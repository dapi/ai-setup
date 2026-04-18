module Operations
  module Tickets
    class ManagerUpdateService < BaseService
      PERMITTED_ATTRIBUTES = %i[staff_id status].freeze

      option :manager
      option :ticket
      option :params

      def call
        failure_result = precondition_failure

        return failure_result if failure_result

        apply_changes

        return failure_for(ticket, :validation_failed, ticket.errors.full_messages) if ticket.errors.any?

        persist_ticket
      end

      private

      def precondition_failure
        return failure_for(ticket, :forbidden, "Ticket must belong to the manager hotel") unless same_hotel_ticket?

        invalid_status_failure if invalid_status?
      end

      def apply_changes
        assign_staff if permitted_params.key?(:staff_id)
        ticket.status = permitted_params[:status] if permitted_params.key?(:status)
      end

      def persist_ticket
        if ticket.save
          success(result: ticket)
        else
          failure(error_code: :validation_failed, messages: ticket.errors.full_messages, result: ticket)
        end
      end

      def same_hotel_ticket?
        ticket.hotel_id == manager.hotel_id
      end

      def permitted_params
        @permitted_params ||= raw_params.slice(*PERMITTED_ATTRIBUTES)
      end

      def raw_params
        params_hash = params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h : params.to_h

        params_hash.with_indifferent_access
      end

      def invalid_status?
        permitted_params.key?(:status) && !Ticket.statuses.key?(permitted_params[:status])
      end

      def invalid_status_failure
        failure_for(ticket, :validation_failed, "Status is invalid")
      end

      def assign_staff
        staff_id = permitted_params[:staff_id]

        return unassign_staff if staff_id.blank?

        assignee = ::Staff.find_by(id: staff_id)
        error_message = assignee_error_message(assignee)

        if error_message
          ticket.errors.add(:staff, error_message)
        else
          ticket.staff = assignee
        end
      end

      def unassign_staff
        ticket.staff = nil
      end

      def assignee_error_message(assignee)
        return "is invalid" if assignee.blank?
        return "must belong to the same hotel" if assignee.hotel_id != manager.hotel_id

        "must have staff role" unless assignee.staff?
      end

      def failure_for(record, error_code, messages)
        messages = Array(messages)

        failure(error_code: error_code, messages: messages, result: record)
      end
    end
  end
end
