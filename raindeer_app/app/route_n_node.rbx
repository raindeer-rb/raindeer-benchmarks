# frozen_string_literal: true

class RouteNNode < LowNode
  (1..100).each { |i| observe "/route#{i}" }

  def render
    "Route\n"
  end
end
