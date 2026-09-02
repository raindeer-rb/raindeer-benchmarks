# frozen_string_literal: true

class HomeController < ApplicationController
  def show
    render plain: "Welcome to Rails\n"
  end

  def slow
    sleep(0.05) # Simulates a blocking downstream I/O call (DB query, HTTP request, etc).
    render plain: "Slow response\n"
  end

  def route_n
    render plain: "Route\n"
  end
end
