# frozen_string_literal: true

class RouteNNode < LowNode
  (1..400).each { |i| observe "/route#{i}" }
  (1..10).each { |g| (1..30).each { |i| observe "/pair#{g}/leaf#{i}" } }
  (1..10).each { |g| (1..10).each { |m| (1..3).each { |i| observe "/trio#{g}/mid#{m}/leaf#{i}" } } }

  def render
    "Route\n"
  end
end
