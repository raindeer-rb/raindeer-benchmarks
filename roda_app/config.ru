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

    # 1000 routes total, mixed depth, coexisting -- the way a real app's
    # route table actually looks, rather than uniformly flat or uniformly
    # deep. 400 flat, 300 nested two segments deep (10 groups x 30 leaves),
    # 300 nested three segments deep (10x10x3). The 2/3-segment groups use
    # r.on -- Roda's routing-tree primitive -- so a failed group match skips
    # every leaf under it, instead of checking each one individually.
    (1..400).each do |i|
      r.get "route#{i}" do
        "Route #{i}\n"
      end
    end

    (1..10).each do |g|
      r.on "pair#{g}" do
        (1..30).each do |i|
          r.get "leaf#{i}" do
            "Route #{g}-#{i}\n"
          end
        end
      end
    end

    (1..10).each do |g|
      r.on "trio#{g}" do
        (1..10).each do |m|
          r.on "mid#{m}" do
            (1..3).each do |i|
              r.get "leaf#{i}" do
                "Route #{g}-#{m}-#{i}\n"
              end
            end
          end
        end
      end
    end

    nil # the route block's return value is the fallback response body for
        # any unmatched request -- without this, it'd be whichever Enumerable
        # the last route-registration loop above happened to return, which
        # Roda can't render and raises on (500 instead of a plain 404).
  end
end

run App.freeze.app
