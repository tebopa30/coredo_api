Rails.application.routes.draw do
  scope :api do
    # 質問系
    get  'questions/start', to: 'questions#start'
    get  'questions/:id',   to: 'questions#show'
    post 'questions/ai_answer', to: 'questions#ai_answer'
    post 'questions/answer', to: 'questions#answer'

    # 回答系
    post 'answers',         to: 'answers#create'
    post 'answers/finish',  to: 'answers#finish'

    # 結果系
    get  'results/:session_id', to: 'results#show'

    # その他
    get  'dishes/:id',      to: 'dishes#show'
    get  'dishes/:id/places', to: 'places#nearby'
    get  'dishes/:id/recipes', to: 'recipes#index'
    get  'history/:session_id', to: 'history#index'
    get  'places/search', to: 'places#search'
    get  'places/details', to: 'places#details'
    get  'places/geocode', to: 'places#geocode'
    get  'places/directions', to: 'places#directions'
  end

  get "up" => "rails/health#show", as: :rails_health_check
end