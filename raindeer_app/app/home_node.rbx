# frozen_string_literal: true

class HomeNode < LowNode
  observe '/'

  def render
    "Welcome to Raindeer\n"
  end
end
