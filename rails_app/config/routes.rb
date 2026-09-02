Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  root "home#show"
  get "/slow" => "home#slow"

  # 100 extra routes to test router scaling -- /route100 is the longest path.
  (1..100).each { |i| get "/route#{i}" => "home#route_n" }
end
