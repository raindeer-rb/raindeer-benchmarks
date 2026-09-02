# frozen_string_literal: true

require 'sinatra/base'

class App < Sinatra::Base
  get '/' do
    "Welcome to Sinatra\n"
  end

  get '/slow' do
    sleep(0.05) # Simulates a blocking downstream I/O call (DB query, HTTP request, etc).
    "Slow response\n"
  end

  # 100 extra routes to test router scaling -- /route100 is the longest path.
  (1..100).each do |i|
    get "/route#{i}" do
      "Route #{i}\n"
    end
  end
end

run App.new
