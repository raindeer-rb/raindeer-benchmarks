# frozen_string_literal: true

module HanamiApp
  module Actions
    module Home
      class Show < HanamiApp::Action
        def handle(request, response)
          response.body = "Welcome to Hanami\n"
        end
      end
    end
  end
end
