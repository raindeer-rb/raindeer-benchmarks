# frozen_string_literal: true

module HanamiApp
  module Actions
    module Home
      class Slow < HanamiApp::Action
        def handle(request, response)
          sleep(0.05) # Simulates a blocking downstream I/O call (DB query, HTTP request, etc).
          response.body = "Slow response\n"
        end
      end
    end
  end
end
