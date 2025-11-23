Rails.application.routes.draw do

  scope :api do
    get  'questions/start', to: 'questions#start'
    get  'questions/:id',   to: 'questions#show'
    post 'answers',         to: 'answers#create'
    get  'results/:session_id', to: 'results#show'
    get  'dishes/:id',      to: 'dishes#show'
    get  'dishes/:id/places', to: 'places#nearby'
    get  'dishes/:id/recipes', to: 'recipes#index'
    get  'history/:session_id', to: 'history#index'
  end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"
end
