Rails.application.routes.draw do
  # Health check for load balancers / uptime monitors
  get "up" => "rails/health#show", as: :rails_health_check

  # --- Public pages ---
  root "pages#home"
  get "about", to: "pages#about"

  # --- Issues (accountability scorecards) ---
  resources :issues, only: [:index, :show]

  # --- Representatives ---
  resources :representatives, only: [:index, :show]

  # --- Bills ---
  resources :bills, only: [:index, :show]
end
