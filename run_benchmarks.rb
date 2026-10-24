#!/usr/bin/env ruby
# frozen_string_literal: true

# Runs the full 8-way benchmark (Raindeer+LowLoop/Falcon/Iodine, Roda+Falcon,
# Rage+Iodine, Sinatra+Falcon, Hanami+Falcon, Rails+Falcon) four times against
# each server -- GET /, plus one route each at 1, 2, and 3 path segments deep.
# Each app registers ONE mixed-depth route table of 1000 routes, coexisting in
# a single process, the way a real app's router actually looks, mirroring the
# common REST nested-resource pattern -- a resource is independently
# addressable AND has children (/orgs/5, then /orgs/5/repos/3, then
# /orgs/5/repos/3/issues/2) -- rather than inventing disjoint namespaces that
# only ever exist to create depth: 390 plain "solo" leaves (/solo11..400);
# solo1..10 double as duo parents, each with 20 plain "duo" leaves
# (/solo1/duo11..30, etc.) plus 10 duo1..10 that double as trio parents, each
# with 3 "trio" leaves (/solo1/duo1/trio1..3, etc.) -- 390 + 10 + 200 + 100 +
# 300 = 1000 routes total.
#
# Only Roda's 2/3-segment groups are genuinely nested (via r.on) -- reading
# every other framework's router source confirmed nesting doesn't change
# matching cost for them, so their 2/3-segment routes are declared as flat,
# full path strings like their 1-segment ones: Rails/Hanami/Rage compile to a
# shared DFA/radix structure regardless of whether the DSL used a flat loop
# or scope/namespace nesting; Raindeer's router is a segment-level trie that
# prefix-shares regardless of DSL nesting; and Sinatra's Sinatra::Namespace
# doesn't create any different structure at all -- it's registration-time
# string concatenation into the exact same flat, linearly-scanned list
# (measured to make things slightly worse than flat, not better). Roda's
# r.on is the only construct here that actually changes what gets checked
# per request. Writes benchmark-report.html (one plain, unstyled HTML table,
# one row per server) in this directory. Re-run any time with:
#
#   ruby run_benchmarks.rb
#
# Pass --hide-iodine to leave the Iodine-based servers out of the HTML table
# (they're still benchmarked and shown in the terminal summary).
#
# Method: `ab -n 2000 -c 25 -k` warm-up (discarded), then `ab -n 20000 -c 50 -k`
# measured, against each server one at a time (never concurrently, to avoid CPU
# contention skewing results). Each server runs as a single reactor/process --
# no multi-core forking -- for a fair comparison.

require 'net/http'
require 'timeout'
require 'fileutils'

ROOT = __dir__
RUBY_BIN = File.expand_path('~/.local/share/mise/installs/ruby/3.4.2/bin')
ENV['PATH'] = "#{RUBY_BIN}:#{ENV['PATH']}"

READY_PATH = '/'
# The middle member of each route family (solo11..400, duo11..30 within
# solo1..10, trio1..3 within duo1..10), not the last one declared: Sinatra
# and Roda match in declaration order, so a route near the end of the list is
# their worst case, not a typical request.
TEST_PATHS = {
  'GET /' => '/',
  '1 segment' => '/solo200',
  '2 segments' => '/solo5/duo15',
  '3 segments' => '/solo5/duo5/trio2'
}.freeze

HIDE_IODINE = ARGV.include?('--hide-iodine')

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
    name: 'Raindeer + Iodine',
    dir: 'raindeer_app',
    cmd: 'bundle exec ruby iodine_boot.rb',
    env: { 'PORT' => '9298' },
    port: 9298
  },
  {
    name: 'Rage + Iodine',
    dir: 'rage_app',
    cmd: 'bundle exec rage s -p 9297 -e production',
    env: {},
    port: 9297
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
  %w[falcon\ serve bin/server rage\ s iodine_boot.rb].each do |pattern|
    system("pkill -f '#{pattern}'", out: File::NULL, err: File::NULL)
  end
  sleep 1
end

def wait_until_ready(port, timeout: 20)
  deadline = Time.now + timeout
  loop do
    begin
      Net::HTTP.start('127.0.0.1', port, open_timeout: 1, read_timeout: 1) { |http| http.head(READY_PATH) }
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

def run_ab(args, port, path)
  `ab #{args.join(' ')} http://127.0.0.1:#{port}#{path} 2>&1`
end

def parse_ab(output)
  {
    reqs: output[/Requests per second:\s+([\d.]+)/, 1].to_f,
    mean: output[/Time per request:\s+([\d.]+) \[ms\] \(mean\)/, 1].to_f,
    p50: output[/^\s*50%\s+(\d+)/, 1].to_i,
    p90: output[/^\s*90%\s+(\d+)/, 1].to_i,
    p99: output[/^\s*99%\s+(\d+)/, 1].to_i,
    failed: output[/Failed requests:\s+(\d+)/, 1].to_i,
    non_2xx: output[/Non-2xx responses:\s+(\d+)/, 1].to_i,
    complete: output[/Complete requests:\s+(\d+)/, 1].to_i
  }
end

def with_commas(number, decimals:)
  whole, frac = format("%.#{decimals}f", number).split('.')
  whole = whole.reverse.gsub(/(\d{3})(?=\d)/, '\1,').reverse
  frac ? "#{whole}.#{frac}" : whole
end

# "Roda + Falcon" -> "<strong>Roda</strong> + Falcon": bold the framework, not the server.
def bold_framework(name)
  framework, server = name.split(' + ', 2)
  server ? "<strong>#{framework}</strong> + #{server}" : "<strong>#{framework}</strong>"
end

# One row per server, one Req/s column per benchmarked path (sorted by the
# first path's Req/s), plus mean latency for the last path only (the highest
# route count -- the most demanding, most differentiating column).
def render_table(results_by_label)
  labels = results_by_label.keys
  latency_label = labels.last
  names = results_by_label[labels.first].map { |r| r[:name] }

  stats_by_name = names.to_h do |name|
    [name, labels.to_h { |label| [label, results_by_label[label].find { |r| r[:name] == name }] }]
  end

  sorted_names = names.sort_by { |name| -stats_by_name[name][labels.first][:reqs] }

  header_cells = ['<th>Server</th>', *labels.map { |label| "<th>#{label} (req/s)</th>" },
                   "<th>Mean latency (#{latency_label})</th>"].join("\n      ")

  rows = sorted_names.map do |name|
    cells = [
      "<td>#{bold_framework(name)}</td>",
      *labels.map { |label| "<td>#{with_commas(stats_by_name[name][label][:reqs], decimals: 2)}</td>" },
      "<td>#{with_commas(stats_by_name[name][latency_label][:mean], decimals: 3)} ms</td>"
    ]

    "<tr>\n  #{cells.join("\n  ")}\n</tr>\n"
  end.join

  # Indent every line of every row so <tr>/<td> land properly nested beneath <tbody>.
  indented_rows = rows.each_line.map { |line| line.strip.empty? ? line : "    #{line}" }.join.chomp

  <<~TABLE
    <table>
      <thead>
        <tr>
          #{header_cells}
        </tr>
      </thead>
      <tbody>
    #{indented_rows}
      </tbody>
    </table>
  TABLE
end

def print_summary(results_by_label)
  results_by_label.each do |label, results|
    puts
    puts label
    puts format('%-20s %12s %14s %8s %8s %8s %8s', 'Server', 'Req/s', 'Mean (ms)', 'p50', 'p90', 'p99', 'Failed')
    results.sort_by { |r| -r[:reqs] }.each do |r|
      puts format('%-20s %12.2f %14.3f %8d %8d %8d %8d', r[:name], r[:reqs], r[:mean], r[:p50], r[:p90], r[:p99], r[:failed])
    end
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

  results_by_label = TEST_PATHS.to_h { |label, _path| [label, []] }

  TARGETS.each do |target|
    TEST_PATHS.each do |label, path|
      puts "Benchmarking #{target[:name]} (#{label}, warm-up)..."
      run_ab(WARMUP_ARGS, target[:port], path)

      puts "Benchmarking #{target[:name]} (#{label}, measured)..."
      output = run_ab(MEASURE_ARGS, target[:port], path)
      stats = parse_ab(output)

      if stats[:complete] != 20_000 || stats[:failed] != 0 || stats[:non_2xx] != 0
        warn "  WARNING: #{target[:name]} (#{label}) -- complete=#{stats[:complete]} failed=#{stats[:failed]} non-2xx=#{stats[:non_2xx]}"
      end

      results_by_label[label] << stats.merge(name: target[:name])
    end
  end

  print_summary(results_by_label)

  out_path = File.join(ROOT, 'benchmark-report.html')
  html_results = results_by_label.transform_values do |results|
    HIDE_IODINE ? results.reject { |r| r[:name].downcase.include?('iodine') } : results
  end
  report = <<~HTML
    <title>Raindeer Benchmarks</title>

    #{render_table(html_results)}
  HTML
  File.write(out_path, report)
  puts "Wrote #{out_path}"
ensure
  puts 'Stopping all servers...'
  pids.each_value { |pid| stop(pid) }
end
