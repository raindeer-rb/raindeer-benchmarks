# frozen_string_literal: true

class RouteNNode < LowNode
  (11..400).each { |s| observe "/solo#{s}" }
  (1..10).each do |s|
    observe "/solo#{s}"
    (11..30).each { |d| observe "/solo#{s}/duo#{d}" }
    (1..10).each do |d|
      observe "/solo#{s}/duo#{d}"
      (1..3).each { |t| observe "/solo#{s}/duo#{d}/trio#{t}" }
    end
  end

  def render
    "Route\n"
  end
end
