# frozen_string_literal: true

# rage-iodine's exe/iodine and Rack::Handler::Iodine are both hard-wired to boot
# a Rage app (Rage::CLI) unconditionally when Rage::CLI is loadable, which it
# always is in this bundle. Bypassing both and driving Iodine's own public API
# directly instead -- this is the documented, non-deprecated way to run a plain
# Rack app on Iodine (see Iodine.listen2http's deprecation note).

require 'iodine'
require_relative 'rack_adapter'

Iodine.threads = 1
Iodine.workers = 1

Iodine.listen(service: :http, handler: RaindeerRackAdapter.new, port: ENV.fetch('PORT', '9300'), address: ENV.fetch('BIND', '127.0.0.1'))
Iodine.start
