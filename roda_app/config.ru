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

    # 1000 routes total, mirroring the common REST nested-resource pattern:
    # a resource is independently addressable AND has children (/orgs/5,
    # then /orgs/5/repos/3, then /orgs/5/repos/3/issues/2) rather than
    # inventing disjoint namespaces that only ever exist to create depth.
    # solo1..10 double as both ordinary solo leaves and duo parents;
    # duo1..10 (within each of those) double as both ordinary duo leaves and
    # trio parents. r.on -- Roda's routing-tree primitive -- means a failed
    # solo/duo prefix match skips every route nested under it, instead of
    # checking each one individually.
    #
    # Ordering matters: the route block runs top to bottom on every request,
    # so r.on branches (fail fast -- one string-prefix mismatch skips the
    # whole subtree) are registered before the large flat block of plain
    # solo leaves (fails slow -- one entry checked at a time). Registering
    # them the other way around made every nested request pay for 390 wasted
    # flat checks before ever reaching the branch that would actually match
    # -- measured at a 3.5x throughput cost for no benefit to the flat-leaf
    # case, which pays roughly the same either way.

    # solo1..10 are also duo parents.
    (1..10).each do |s|
      r.on "solo#{s}" do
        r.get true do
          "Route #{s}\n"
        end

        # duo1..10 (within this solo) are also trio parents.
        (1..10).each do |d|
          r.on "duo#{d}" do
            r.get true do
              "Route #{s}-#{d}\n"
            end

            (1..3).each do |t|
              r.get "trio#{t}" do
                "Route #{s}-#{d}-#{t}\n"
              end
            end
          end
        end

        # Plain duo leaves, no children.
        (11..30).each do |d|
          r.get "duo#{d}" do
            "Route #{s}-#{d}\n"
          end
        end
      end
    end

    # Plain solo leaves, no children.
    (11..400).each do |s|
      r.get "solo#{s}" do
        "Route #{s}\n"
      end
    end

    nil # the route block's return value is the fallback response body for
        # any unmatched request -- without this, it'd be whichever Enumerable
        # the last route-registration loop above happened to return, which
        # Roda can't render and raises on (500 instead of a plain 404).
  end
end

run App.freeze.app
