# frozen_string_literal: true

Rage.routes.draw do
  root to: ->(_env) { [200, {}, ["Welcome to Rage\n"]] }

  get 'slow', to: lambda { |_env|
    sleep(0.05) # Simulates a blocking downstream I/O call (DB query, HTTP request, etc).
    [200, {}, ["Slow response\n"]]
  }

  # 100 extra routes to test router scaling -- /route100 is the longest path.
  (1..100).each do |i|
    get "route#{i}", to: ->(_env) { [200, {}, ["Route #{i}\n"]] }
  end
end
