module Operations
  module Staff
    class CreateService < BaseService
      PERMITTED_ATTRIBUTES = %i[
        name
        email
        password
        password_confirmation
        department_id
      ].freeze

      option :manager
      option :params

      def call
        staff = ::Staff.new(permitted_params.merge(hotel: manager.hotel, role: :staff))

        return cross_hotel_department_failure(staff) if cross_hotel_department?

        if staff.save
          success(result: staff)
        else
          failure(error_code: :validation_failed, messages: staff.errors.full_messages, result: staff)
        end
      end

      private

      def permitted_params
        @permitted_params ||= raw_params.slice(*PERMITTED_ATTRIBUTES)
      end

      def raw_params
        params_hash = params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h : params.to_h

        params_hash.with_indifferent_access
      end

      def cross_hotel_department?
        department_id = permitted_params[:department_id]

        department_id.present? && !manager.hotel.departments.exists?(id: department_id)
      end

      def cross_hotel_department_failure(staff)
        staff.errors.add(:department, "must belong to the same hotel")

        failure(error_code: :validation_failed, messages: staff.errors.full_messages, result: staff)
      end
    end
  end
end
