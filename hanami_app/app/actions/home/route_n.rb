# frozen_string_literal: true

module HanamiApp
  module Actions
    module Home
      class RouteN < HanamiApp::Action
        def handle(request, response)
          response.body = "Route\n"
        end
      end
    end
  end
end
