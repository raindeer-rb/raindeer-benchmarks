# frozen_string_literal: true

# Bridges a plain Rack env to Raindeer's transport-agnostic Router/LowNode/Observer
# pipeline, bypassing LowLoop entirely. This works because everything downstream of
# LowLoop -- Router#handle, LowNode#render, Low::Factories::ResponseFactory -- already
# operates on Protocol::HTTP::Request/Response (the same objects Falcon/async-http use),
# not raw sockets. LowLoop's only job is: accept socket -> parse bytes into a
# Protocol::HTTP::Request -> Low::Events::RequestEvent.take(request:) -> serialize the
# Protocol::HTTP::Response back to bytes. This adapter does the same first and last
# steps via Rack instead, so any Rack server (Iodine included) can drive Raindeer's
# router without LowLoop ever being instantiated.

require 'bundler/setup'
require 'rack'
require 'raindeer/boot'

# Normally done inside LowLoop#initialize -- replicated here since we never build a
# LowLoop instance (that's the whole point: skip its socket/transport layer).
Low::Events::RequestEvent.define do |observers|
  observers << Providers['rain.router']
end

class RaindeerRackAdapter
  def call(env)
    request = Rack::Request.new(env)

    body = request.body&.read
    body = nil if body.nil? || body.empty?

    headers = Protocol::HTTP::Headers.new(
      env.filter_map do |key, value|
        next unless key.start_with?('HTTP_')

        [key.delete_prefix('HTTP_').tr('_', '-').downcase, value]
      end
    )

    # request.scheme/request.host/request.port run Rack's reverse-proxy-aware
    # Forwarded/X-Forwarded-* resolution chain (regex-heavy) on every request.
    # Profiled with stackprof: that resolution alone was ~63% of this method's
    # CPU time. There's no proxy in front of this benchmark, so read the plain
    # Rack env values directly instead.
    http_request = Protocol::HTTP::Request.new(
      env['rack.url_scheme'],
      env['HTTP_HOST'] || "#{env['SERVER_NAME']}:#{env['SERVER_PORT']}",
      request.request_method,
      request.fullpath,
      'HTTP/1.1',
      headers,
      body
    )

    response_event = Low::Events::RequestEvent.take(request: http_request)
    response = response_event.response

    body_data = response.body.respond_to?(:file) ? File.binread(response.body.file.path) : (response.body.read || '')

    rack_headers = {}
    response.headers.fields.each { |key, value| rack_headers[key.to_s] = value.to_s }
    rack_headers['content-length'] ||= body_data.bytesize.to_s

    [response.status, rack_headers, [body_data]]
  end
end
