Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  root "home#index"

  namespace :admin do
    root "hotels#index"

    resources :hotels, param: :slug do
      resources :staff, only: %i[index show], controller: "hotel_staff"
      resources :tickets, only: :index, controller: "hotel_tickets"
    end

    resources :staff, only: :index
    resources :tickets, only: :index
  end
end
