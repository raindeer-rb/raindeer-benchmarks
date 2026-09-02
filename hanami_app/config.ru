# frozen_string_literal: true

require "hanami/boot"

if ENV["COUNT_ALLOCS"]
  # Wraps the full request cycle -- Hanami's router + Hanami::Action pipeline --
  class AllocCounter
    def initialize(app)
      @app = app
    end

    def call(env)
      GC.disable
      before = GC.stat(:total_allocated_objects)
      response = @app.call(env)
      after = GC.stat(:total_allocated_objects)
      warn "ALLOCS: #{after - before}"
      response
    end
  end

  run AllocCounter.new(Hanami.app)
else
  run Hanami.app
end
