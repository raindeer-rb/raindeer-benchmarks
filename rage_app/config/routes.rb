# frozen_string_literal: true

Rage.routes.draw do
  root to: ->(_env) { [200, {}, ["Welcome to Rage\n"]] }

  get 'slow', to: lambda { |_env|
    sleep(0.05) # Simulates a blocking downstream I/O call (DB query, HTTP request, etc).
    [200, {}, ["Slow response\n"]]
  }

  # 1000 routes total, mirroring the common REST nested-resource pattern: a
  # resource is independently addressable AND has children (/orgs/5, then
  # /orgs/5/repos/3, then /orgs/5/repos/3/issues/2) rather than inventing
  # disjoint namespaces that only ever exist to create depth. solo1..10
  # double as both ordinary solo leaves and duo parents; duo1..10 (within
  # each of those) double as both ordinary duo leaves and trio parents. All
  # registered as flat, full path strings rather than via `scope`, since
  # Rage's router is a radix tree (based on find-my-way) regardless of
  # whether the DSL used a flat loop or `scope` nesting (confirmed by
  # reading the gem's source) -- nesting wouldn't change dispatch cost here
  # either way.

  # Plain solo leaves, no children.
  (11..400).each do |s|
    get "solo#{s}", to: ->(_env) { [200, {}, ["Route #{s}\n"]] }
  end

  (1..10).each do |s|
    # solo1..10 are also duo parents.
    get "solo#{s}", to: ->(_env) { [200, {}, ["Route #{s}\n"]] }

    # Plain duo leaves, no children.
    (11..30).each do |d|
      get "solo#{s}/duo#{d}", to: ->(_env) { [200, {}, ["Route #{s}-#{d}\n"]] }
    end

    # duo1..10 (within this solo) are also trio parents.
    (1..10).each do |d|
      get "solo#{s}/duo#{d}", to: ->(_env) { [200, {}, ["Route #{s}-#{d}\n"]] }

      (1..3).each do |t|
        get "solo#{s}/duo#{d}/trio#{t}", to: ->(_env) { [200, {}, ["Route #{s}-#{d}-#{t}\n"]] }
      end
    end
  end
end
