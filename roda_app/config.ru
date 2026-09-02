# frozen_string_literal: true

require 'roda'

class App < Roda
  route do |r|
    r.root do
      "Welcome to Roda\n"
    end

    r.get 'slow' do
      sleep(0.05) # Simulates a blocking downstream I/O call (DB query, HTTP request, etc).
      "Slow response\n"
    end

    # 100 extra routes to test router scaling -- /route100 is the longest path.
    (1..100).each do |i|
      r.get "route#{i}" do
        "Route #{i}\n"
      end
    end
  end
end

run App.freeze.app
