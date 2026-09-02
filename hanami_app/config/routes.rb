# frozen_string_literal: true

module HanamiApp
  class Routes < Hanami::Routes
    root to: "home.show"
    get "/slow", to: "home.slow"

    # 100 extra routes to test router scaling -- /route100 is the longest path.
    (1..100).each { |i| get "/route#{i}", to: "home.route_n" }
  end
end
