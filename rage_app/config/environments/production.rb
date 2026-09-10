# frozen_string_literal: true

Rage.configure do
  # Single worker process/reactor, to match the other benchmarked apps
  # (no multi-core forking -- see README's "Method" section).
  config.server.workers_count = 1

  config.logger = Rage::Logger.new(STDOUT)
  config.log_level = Logger::INFO
end
