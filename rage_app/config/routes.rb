# frozen_string_literal: true

Rage.routes.draw do
  root to: ->(_env) { [200, {}, ["Welcome to Rage\n"]] }

  get 'slow', to: lambda { |_env|
    sleep(0.05) # Simulates a blocking downstream I/O call (DB query, HTTP request, etc).
    [200, {}, ["Slow response\n"]]
  }

  # 1000 routes total, mixed depth, coexisting -- the way a real app's route
  # table actually looks. 400 flat, 300 two segments deep (10 groups x 30
  # leaves), 300 three segments deep (10x10x3) -- all registered as flat,
  # full path strings rather than via `scope`, since Rage's router is a
  # radix tree (based on find-my-way) regardless of whether the DSL used a
  # flat loop or `scope` nesting (confirmed by reading the gem's source) --
  # nesting wouldn't change dispatch cost here either way.
  (1..400).each do |i|
    get "route#{i}", to: ->(_env) { [200, {}, ["Route #{i}\n"]] }
  end

  (1..10).each do |g|
    (1..30).each do |i|
      get "pair#{g}/leaf#{i}", to: ->(_env) { [200, {}, ["Route #{g}-#{i}\n"]] }
    end
  end

  (1..10).each do |g|
    (1..10).each do |m|
      (1..3).each do |i|
        get "trio#{g}/mid#{m}/leaf#{i}", to: ->(_env) { [200, {}, ["Route #{g}-#{m}-#{i}\n"]] }
      end
    end
  end
end
