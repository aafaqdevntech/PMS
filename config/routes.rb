Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  post "/auth/login", to: "auth#login"
  post "/auth/refresh", to: "auth#refresh"

  post "/password/forgot", to: "passwords#create"
  patch "/password/reset", to: "passwords#update"

  get "/me", to: "users#me"

  resources :users, only: [:index, :show, :create, :update, :destroy] do
    resource :profile, only: [:show, :create, :update, :destroy]
    resource :employment_detail, only: [:show, :create, :update, :destroy]
  end

  resources :teams

  resources :projects, only: [:index, :show, :create, :update, :destroy] do
    member do
      post :assign_team
      delete :unassign_team
    end

    resources :issues, only: [:index, :create]
  end

  resources :issues, only: [:show, :update, :destroy] do
    member do
      post :resolve
      post :reject
    end
  end

  # Defines the root path route ("/")
  # root "posts#index"
end
