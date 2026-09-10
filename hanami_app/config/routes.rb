# frozen_string_literal: true

module HanamiApp
  class Routes < Hanami::Routes
    root to: "home.show"
    get "/slow", to: "home.slow"

    # 1000 routes total, mixed depth, coexisting -- the way a real app's
    # route table actually looks. 400 flat, 300 two segments deep (10 groups
    # x 30 leaves), 300 three segments deep (10x10x3) -- all registered as
    # flat, full path strings rather than via `scope`, since Hanami::Router
    # is a radix trie (hash lookup per segment) regardless of whether routes
    # are declared flat or via `scope` (confirmed by reading hanami-router's
    # source) -- nesting wouldn't change dispatch cost here either way.
    (1..400).each { |i| get "/route#{i}", to: "home.route_n" }

    (1..10).each do |g|
      (1..30).each { |i| get "/pair#{g}/leaf#{i}", to: "home.route_n" }
    end

    (1..10).each do |g|
      (1..10).each do |m|
        (1..3).each { |i| get "/trio#{g}/mid#{m}/leaf#{i}", to: "home.route_n" }
      end
    end
  end
end
