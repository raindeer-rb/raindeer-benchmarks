# frozen_string_literal: true

class SlowNode < LowNode
  observe '/slow'

  def render
    sleep(0.05) # Simulates a blocking downstream I/O call (DB query, HTTP request, etc).
    "Slow response\n"
  end
end
