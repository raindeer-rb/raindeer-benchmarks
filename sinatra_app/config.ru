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

  # 1000 routes total, mixed depth, coexisting -- the way a real app's route
  # table actually looks. 400 flat, 300 two segments deep (10 groups x 30
  # leaves), 300 three segments deep (10x10x3) -- all registered as flat,
  # full path strings rather than via Sinatra::Namespace, since nesting there
  # is registration-time string concatenation into the exact same flat,
  # linearly-scanned route list (confirmed by reading sinatra-contrib's
  # source) -- it doesn't help, and measured slightly worse than this, likely
  # from the extra composed-Mustermann-pattern overhead per check.
  (1..400).each do |i|
    get "/route#{i}" do
      "Route #{i}\n"
    end
  end

  (1..10).each do |g|
    (1..30).each do |i|
      get "/pair#{g}/leaf#{i}" do
        "Route #{g}-#{i}\n"
      end
    end
  end

  (1..10).each do |g|
    (1..10).each do |m|
      (1..3).each do |i|
        get "/trio#{g}/mid#{m}/leaf#{i}" do
          "Route #{g}-#{m}-#{i}\n"
        end
      end
    end
  end
end

run App.new
