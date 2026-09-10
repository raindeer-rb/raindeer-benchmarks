# frozen_string_literal: true

module HanamiApp
  class Routes < Hanami::Routes
    root to: "home.show"
    get "/slow", to: "home.slow"

    # 1000 routes total, mirroring the common REST nested-resource pattern: a
    # resource is independently addressable AND has children (/orgs/5, then
    # /orgs/5/repos/3, then /orgs/5/repos/3/issues/2) rather than inventing
    # disjoint namespaces that only ever exist to create depth. solo1..10
    # double as both ordinary solo leaves and duo parents; duo1..10 (within
    # each of those) double as both ordinary duo leaves and trio parents. All
    # registered as flat, full path strings rather than via `scope`, since
    # Hanami::Router is a radix trie (hash lookup per segment) regardless of
    # whether routes are declared flat or via `scope` (confirmed by reading
    # hanami-router's source) -- nesting wouldn't change dispatch cost here
    # either way.

    # Plain solo leaves, no children.
    (11..400).each { |s| get "/solo#{s}", to: "home.route_n" }

    (1..10).each do |s|
      # solo1..10 are also duo parents.
      get "/solo#{s}", to: "home.route_n"

      # Plain duo leaves, no children.
      (11..30).each { |d| get "/solo#{s}/duo#{d}", to: "home.route_n" }

      # duo1..10 (within this solo) are also trio parents.
      (1..10).each do |d|
        get "/solo#{s}/duo#{d}", to: "home.route_n"
        (1..3).each { |t| get "/solo#{s}/duo#{d}/trio#{t}", to: "home.route_n" }
      end
    end
  end
end
