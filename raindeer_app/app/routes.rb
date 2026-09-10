# frozen_string_literal: true

Raindeer.router do
  get '/'
  get '/slow'

  # 1000 routes total, mixed depth, coexisting -- the way a real app's route
  # table actually looks. 400 flat, 300 two segments deep (10 groups x 30
  # leaves), 300 three segments deep (10x10x3) -- all registered as flat,
  # full path strings rather than via `get`'s nested-block form (see
  # route_n_node.rbx for the matching observers), since Raindeer's router is
  # a segment-level trie that prefix-shares regardless of DSL nesting
  # (confirmed by reading the gem's source) -- nesting wouldn't change
  # dispatch cost here either way.
  (1..400).each { |i| get "/route#{i}" }

  (1..10).each do |g|
    (1..30).each { |i| get "/pair#{g}/leaf#{i}" }
  end

  (1..10).each do |g|
    (1..10).each do |m|
      (1..3).each { |i| get "/trio#{g}/mid#{m}/leaf#{i}" }
    end
  end
end
