# frozen_string_literal: true

require 'bundler/setup'
require 'low_type'

# Must run before any Raindeer classes load -- the typed-vs-untyped method
# wrapper is chosen once per class, at class-definition time.
LowType.configure { |config| config.type_checking = false }

require 'raindeer/boot'

# The bundled Matrix "digital rain" renderer crashes on every request (nil
# screen dimensions reach Rain::Matrix#upsert_stream) and LowLoop's own
# show_output default requires a real TTY to set up. Neither is part of
# routing/response handling, so disable the renderer -- the benchmark then
# measures routing/response only, same as roda_app/hanami_app carry no
# extra middleware either.
Providers.define('rain.matrix') { nil }
