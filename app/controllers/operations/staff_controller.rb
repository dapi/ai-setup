module Operations
  class StaffController < BaseController
    before_action :require_manager!

    def index
      @staff_members = current_hotel.staff
                                    .where(role: :staff)
                                    .includes(:department)
                                    .order(:name, :email)
    end

    def new
      @staff_member = ::Staff.new(hotel: current_hotel, role: :staff)
      prepare_departments
    end

    def create
      result = Operations::Staff::CreateService.call(manager: current_staff, params: staff_params)
      @staff_member = result.result

      if result.success?
        redirect_to operations_staff_index_path, notice: "Staff created"
      else
        @result = result
        prepare_departments
        render :new, status: :unprocessable_entity
      end
    end

    private

    def prepare_departments
      @departments = current_hotel.departments.order(:name)
    end

    def staff_params
      params.require(:staff).permit(:name, :email, :password, :password_confirmation, :department_id)
    end
  end
end
