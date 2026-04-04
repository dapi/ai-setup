Rails.application.routes.draw do
  # Redirect to localhost from 127.0.0.1 to use same IP address with Vite server
  constraints(host: "127.0.0.1") do
    get "(*path)", to: redirect { |params, req| "#{req.protocol}localhost:#{req.port}/#{params[:path]}" }
  end

  devise_for :users, controllers: {
    sessions: "users/sessions",
    registrations: "users/registrations",
    confirmations: "users/confirmations"
  }

  # Resend confirmation email (button "Didn't receive email?")
  namespace :users do
    namespace :confirmations do
      resource :resend, only: [ :create ]
    end
  end

  # letter_opener_web (development only)
  mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?

  authenticate :user do
    root "pages#index", as: :authenticated_root
  end

  devise_scope :user do
    root "users/sessions#new"
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
