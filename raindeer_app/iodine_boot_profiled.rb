# frozen_string_literal: true

require 'stackprof'
require 'fileutils'
require 'iodine'
require_relative 'rack_adapter'

duration = (ENV['PROFILE_SECONDS'] || 15).to_i
out = ENV['PROFILE_OUT'] || 'tmp/stackprof-iodine.dump'
FileUtils.mkdir_p(File.dirname(out))

Iodine.threads = 1
Iodine.workers = 1

Iodine.listen(service: :http, handler: RaindeerRackAdapter.new, port: ENV.fetch('PORT', '9300'), address: ENV.fetch('BIND', '127.0.0.1'))

StackProf.start(mode: :cpu, interval: 1000)

Thread.new do
  sleep duration
  StackProf.stop
  File.binwrite(out, Marshal.dump(StackProf.results))
  warn "wrote #{out}"
  exit!
end

Iodine.start
