module Operations
  class HomeController < BaseController
    def index
      redirect_to operations_tickets_path
    end
  end
end
