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

  # 1000 routes total, mirroring the common REST nested-resource pattern: a
  # resource is independently addressable AND has children (/orgs/5, then
  # /orgs/5/repos/3, then /orgs/5/repos/3/issues/2) rather than inventing
  # disjoint namespaces that only ever exist to create depth. solo1..10
  # double as both ordinary solo leaves and duo parents; duo1..10 (within
  # each of those) double as both ordinary duo leaves and trio parents. All
  # registered as flat, full path strings rather than via Sinatra::Namespace,
  # since nesting there is registration-time string concatenation into the
  # exact same flat, linearly-scanned route list (confirmed by reading
  # sinatra-contrib's source) -- it doesn't help, and measured slightly worse
  # than this, likely from the extra composed-Mustermann-pattern overhead per
  # check.

  # Plain solo leaves, no children.
  (11..400).each do |s|
    get "/solo#{s}" do
      "Route #{s}\n"
    end
  end

  # solo1..10 are also duo parents.
  (1..10).each do |s|
    get "/solo#{s}" do
      "Route #{s}\n"
    end

    # Plain duo leaves, no children.
    (11..30).each do |d|
      get "/solo#{s}/duo#{d}" do
        "Route #{s}-#{d}\n"
      end
    end

    # duo1..10 (within this solo) are also trio parents.
    (1..10).each do |d|
      get "/solo#{s}/duo#{d}" do
        "Route #{s}-#{d}\n"
      end

      (1..3).each do |t|
        get "/solo#{s}/duo#{d}/trio#{t}" do
          "Route #{s}-#{d}-#{t}\n"
        end
      end
    end
  end
end

run App.new
