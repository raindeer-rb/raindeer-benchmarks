#!/usr/bin/env ruby
# frozen_string_literal: true

# Runs the full 6-way benchmark (Raindeer+LowLoop/Falcon, Roda+Falcon,
# Sinatra+Falcon, Hanami+Falcon, Rails+Falcon) against GET
# /route100 -- the longest/last-registered of the 100 extra routes each app
# defines (/route1..100), on top of / and /slow -- and writes
# benchmark-report.html (a plain, unstyled HTML table) in this directory.
# Re-run any time with:
#
#   ruby run_full_benchmark.rb
#
# Method: `ab -n 2000 -c 25 -k` warm-up (discarded), then `ab -n 20000 -c 50 -k`
# measured, against each server one at a time (never concurrently, to avoid CPU
# contention skewing results). Each server runs as a single reactor/process --
# no multi-core forking -- for a fair comparison.

require 'net/http'
require 'timeout'
require 'fileutils'

ROOT = __dir__
TEST_PATH = '/route100'

WARMUP_ARGS  = %w[-n 2000  -c 25 -k]
MEASURE_ARGS = %w[-n 20000 -c 50 -k]

TARGETS = [
  {
    name: 'Roda + Falcon',
    dir: 'roda_app',
    cmd: 'bundle exec falcon serve -b http://127.0.0.1:9293 -n 1 -c config.ru',
    env: {},
    port: 9293
  },
  {
    name: 'Raindeer + LowLoop',
    dir: 'raindeer_app',
    cmd: 'bundle exec bin/server',
    env: {},
    port: 4133
  },
  {
    name: 'Raindeer + Falcon',
    dir: 'raindeer_app',
    cmd: 'bundle exec falcon serve -b http://127.0.0.1:9302 -n 1 -c config_falcon_native.rb',
    env: {},
    port: 9302
  },
  {
    name: 'Sinatra + Falcon',
    dir: 'sinatra_app',
    cmd: 'bundle exec falcon serve -b http://127.0.0.1:9295 -n 1 -c config.ru',
    env: { 'RACK_ENV' => 'production' },
    port: 9295
  },
  {
    name: 'Hanami + Falcon',
    dir: 'hanami_app',
    cmd: 'bundle exec falcon serve -b http://127.0.0.1:9294 -n 1 -c config.ru',
    env: { 'HANAMI_ENV' => 'production', 'RACK_ENV' => 'production' },
    port: 9294
  },
  {
    name: 'Rails + Falcon',
    dir: 'rails_app',
    cmd: 'bundle exec falcon serve -b http://127.0.0.1:9296 -n 1 -c config.ru',
    env: { 'RAILS_ENV' => 'production' },
    port: 9296
  }
].freeze

def free_stale_ports!
  # Best-effort cleanup of leftover processes from a previous run that didn't
  # shut down cleanly (e.g. the script was killed mid-run).
  %w[falcon\ serve bin/server].each do |pattern|
    system("pkill -f '#{pattern}'", out: File::NULL, err: File::NULL)
  end
  sleep 1
end

def wait_until_ready(port, timeout: 20)
  deadline = Time.now + timeout
  loop do
    begin
      Net::HTTP.start('127.0.0.1', port, open_timeout: 1, read_timeout: 1) { |http| http.head(TEST_PATH) }
      return true
    rescue StandardError
      raise "timed out waiting for port #{port}" if Time.now > deadline

      sleep 0.3
    end
  end
end

def start(target)
  full_env = ENV.to_h.merge(target[:env])
  pid = Process.spawn(
    full_env,
    target[:cmd],
    chdir: File.join(ROOT, target[:dir]),
    out: File::NULL,
    err: File::NULL,
    pgroup: true
  )
  Process.detach(pid)
  pid
end

def stop(pid)
  Process.kill('TERM', -pid)
rescue Errno::ESRCH
  nil
end

def run_ab(args, port)
  `ab #{args.join(' ')} http://127.0.0.1:#{port}#{TEST_PATH} 2>&1`
end

def parse_ab(output)
  {
    reqs: output[/Requests per second:\s+([\d.]+)/, 1].to_f,
    mean: output[/Time per request:\s+([\d.]+) \[ms\] \(mean\)/, 1].to_f,
    p50: output[/^\s*50%\s+(\d+)/, 1].to_i,
    p90: output[/^\s*90%\s+(\d+)/, 1].to_i,
    p99: output[/^\s*99%\s+(\d+)/, 1].to_i,
    failed: output[/Failed requests:\s+(\d+)/, 1].to_i,
    complete: output[/Complete requests:\s+(\d+)/, 1].to_i
  }
end

def with_commas(number, decimals:)
  whole, frac = format("%.#{decimals}f", number).split('.')
  whole = whole.reverse.gsub(/(\d{3})(?=\d)/, '\1,').reverse
  frac ? "#{whole}.#{frac}" : whole
end

def render_html(results)
  rows = results.sort_by { |r| -r[:reqs] }.map do |r|
    <<~ROW
      <tr>
        <td>#{r[:name]}</td>
        <td>#{with_commas(r[:reqs], decimals: 2)}</td>
        <td>#{with_commas(r[:mean], decimals: 3)} ms</td>
        <td>#{r[:p50]} ms</td>
        <td>#{r[:p90]} ms</td>
        <td>#{r[:p99]} ms</td>
        <td>#{r[:failed]}</td>
      </tr>
    ROW
  end.join

  # Indent every line of every row so <tr>/<td> land properly nested beneath <tbody>.
  indented_rows = rows.each_line.map { |line| line.strip.empty? ? line : "    #{line}" }.join.chomp

  <<~HTML
    <title>Raindeer Benchmarks</title>

    <table>
      <thead>
        <tr>
          <th>Server</th>
          <th>Req/s</th>
          <th>Mean latency</th>
          <th>p50</th>
          <th>p90</th>
          <th>p99</th>
          <th>Failed</th>
        </tr>
      </thead>
      <tbody>
    #{indented_rows}
      </tbody>
    </table>
  HTML
end

def print_summary(results)
  puts
  puts format('%-20s %12s %14s %8s %8s %8s %8s', 'Server', 'Req/s', 'Mean (ms)', 'p50', 'p90', 'p99', 'Failed')
  results.sort_by { |r| -r[:reqs] }.each do |r|
    puts format('%-20s %12.2f %14.3f %8d %8d %8d %8d', r[:name], r[:reqs], r[:mean], r[:p50], r[:p90], r[:p99], r[:failed])
  end
  puts
end

puts 'Cleaning up any stale servers from a previous run...'
free_stale_ports!

pids = {}
begin
  TARGETS.each do |target|
    print "Starting #{target[:name]}... "
    pids[target[:name]] = start(target)
    wait_until_ready(target[:port])
    puts 'ready'
  end

  results = TARGETS.map do |target|
    puts "Benchmarking #{target[:name]} (warm-up)..."
    run_ab(WARMUP_ARGS, target[:port])

    puts "Benchmarking #{target[:name]} (measured)..."
    output = run_ab(MEASURE_ARGS, target[:port])
    stats = parse_ab(output)

    if stats[:complete] != 20_000 || stats[:failed] != 0
      warn "  WARNING: #{target[:name]} -- complete=#{stats[:complete]} failed=#{stats[:failed]}"
    end

    stats.merge(name: target[:name])
  end

  print_summary(results)

  out_path = File.join(ROOT, 'benchmark-report.html')
  File.write(out_path, render_html(results))
  puts "Wrote #{out_path}"
ensure
  puts 'Stopping all servers...'
  pids.each_value { |pid| stop(pid) }
end
