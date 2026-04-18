module Operations
  class TicketsController < BaseController
    before_action :require_manager!, only: %i[edit update]
    before_action :require_staff!, only: %i[start complete]
    before_action :set_ticket, only: %i[show edit update start complete]
    before_action :ensure_ticket_visible!, only: %i[show start complete]

    def index
      @tickets = Operations::Tickets::VisibleTicketsQuery.call(staff: current_staff)
    end

    def show; end

    def edit
      prepare_ticket_form_options
    end

    def update
      result = Operations::Tickets::ManagerUpdateService.call(
        manager: current_staff,
        ticket: @ticket,
        params: ticket_params
      )

      handle_update_result(result)
    end

    def start
      transition_ticket(Operations::Tickets::StartService)
    end

    def complete
      transition_ticket(Operations::Tickets::CompleteService)
    end

    private

    def set_ticket
      @ticket = current_hotel.tickets
                             .includes(:department, :staff)
                             .find(params[:id])
    end

    def ensure_ticket_visible!
      return if current_staff.manager?

      visible = Operations::Tickets::VisibleTicketsQuery.call(staff: current_staff)
                                                        .where(id: @ticket.id)
                                                        .exists?
      not_found unless visible
    end

    def prepare_ticket_form_options
      @assignees = current_hotel.staff
                                .where(role: :staff)
                                .includes(:department)
                                .order(:name, :email)
      @statuses = Ticket.statuses.keys
    end

    def ticket_params
      params.require(:ticket).permit(:staff_id, :status)
    end

    def transition_ticket(service)
      result = service.call(staff: current_staff, ticket: @ticket)

      handle_transition_result(result)
    end

    def handle_update_result(result)
      @ticket = result.result

      if result.success?
        redirect_to operations_ticket_path(@ticket), notice: "Ticket updated"
      else
        @result = result
        prepare_ticket_form_options
        render :edit, status: :unprocessable_entity
      end
    end

    def handle_transition_result(result)
      @ticket = result.result

      if result.success?
        redirect_to operations_ticket_path(@ticket), notice: "Ticket updated"
      else
        @result = result
        render :show, status: :unprocessable_entity
      end
    end
  end
end
