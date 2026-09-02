# frozen_string_literal: true

require 'stackprof'
require 'fileutils'
require 'roda'

duration = (ENV['PROFILE_SECONDS'] || 15).to_i
out = ENV['PROFILE_OUT'] || 'tmp/stackprof-roda-falcon-cpu.dump'
FileUtils.mkdir_p(File.dirname(out))

class App < Roda
  route do |r|
    r.root do
      "Welcome to Roda\n"
    end

    r.get 'slow' do
      sleep(0.05) # Simulates a blocking downstream I/O call (DB query, HTTP request, etc).
      "Slow response\n"
    end
  end
end

StackProf.start(mode: :cpu, interval: 1000)

Thread.new do
  sleep duration
  StackProf.stop
  File.binwrite(out, Marshal.dump(StackProf.results))
  warn "wrote #{out}"
  exit!
end

run App.freeze.app
