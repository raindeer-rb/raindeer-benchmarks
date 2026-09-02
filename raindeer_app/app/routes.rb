# frozen_string_literal: true

Raindeer.router do
  get '/'
  get '/slow'

  # 100 extra routes to test router scaling -- /route100 is the longest path.
  (1..100).each { |i| get "/route#{i}" }
end
