Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  root "home#show"
  get "/slow" => "home#slow"

  # 1000 routes total, mixed depth, coexisting -- the way a real app's route
  # table actually looks. 400 flat, 300 two segments deep (10 groups x 30
  # leaves), 300 three segments deep (10x10x3) -- all registered as flat,
  # full path strings rather than via `scope`, since Rails' Journey router
  # compiles every route into one shared DFA regardless of whether the DSL
  # used a flat loop or `scope` nesting (confirmed by reading actionpack's
  # source) -- nesting wouldn't change dispatch cost here either way.
  (1..400).each { |i| get "/route#{i}" => "home#route_n" }

  (1..10).each do |g|
    (1..30).each { |i| get "/pair#{g}/leaf#{i}" => "home#route_n" }
  end

  (1..10).each do |g|
    (1..10).each do |m|
      (1..3).each { |i| get "/trio#{g}/mid#{m}/leaf#{i}" => "home#route_n" }
    end
  end
end
