Rails.application.routes.draw do
  match "*path", to: "application#options", via: :options
  namespace :webhooks do
    get "messenger", to: "messenger#show"
    post "messenger", to: "messenger#create"
  end

  get "conversations/lookup", to: "conversations#lookup"
  resources :conversation_messages, only: :create
  resources :products, only: [ :index, :create ]

  namespace :api do
    resource :business, only: %i[show update]
    resources :products
    resource :business_policy, only: %i[show update]
    resources :channel_connections, only: %i[index create update destroy]
    resources :users, only: %i[index create update destroy]
    resources :orders, only: %i[index show update] do
      collection { get :export }
      member { post :submit_delivery }
    end
    resources :conversations, only: %i[index show] do
      member do
        post :handover
        post :resume
        post :reply
      end
    end
    resource :analytics, only: :show
    resource :delivery_integration, only: %i[show update]
  end

  namespace :admin do
    resources :businesses, only: %i[index create update]
  end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"
end
