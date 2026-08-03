#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "net/http"
require "securerandom"
require "uri"

BASE_URL = ENV.fetch("RIDEHORIZON_PROXY_BASE_URL", "https://ridehorizon.digitalmercenaries.ai")
LOG_PATH = ENV.fetch(
  "RIDEHORIZON_SMOKE_LOG",
  "/tmp/ridehorizon-proxy-smoke-#{Time.now.utc.strftime('%Y%m%dT%H%M%SZ')}.log"
)

original_stdout = $stdout
original_stderr = $stderr
tee = IO.popen(["tee", LOG_PATH], "w")
$stdout = tee
$stderr = tee
$stdout.sync = true

at_exit do
  outcome = if $!.nil? || ($!.is_a?(SystemExit) && $!.success?)
              "PASS"
            else
              "FAIL"
            end
  puts "#{Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ')} DONE RideHorizon proxy live smoke test: #{outcome}"
  tee.close unless tee.closed?
  $stdout = original_stdout
  $stderr = original_stderr
end

def timestamp
  Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
end

def progress(message)
  puts "#{timestamp} #{message}"
end

def fail_step!(step, reason)
  warn "#{timestamp} #{step}: #{reason}"
  exit 1
end

def parse_json!(response, step)
  JSON.parse(response.body)
rescue JSON::ParserError
  fail_step!(step, "invalid JSON response")
end

progress("START RideHorizon proxy live smoke test; output is sanitised")

def request(method, path, headers: {}, body: nil)
  uri = URI.join(BASE_URL, path)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = uri.scheme == "https"
  http.open_timeout = 35
  http.read_timeout = 70

  request_class = method == :get ? Net::HTTP::Get : Net::HTTP::Post
  req = request_class.new(uri)
  headers.each { |name, value| req[name] = value }
  req.body = JSON.generate(body) if body
  http.request(req)
end

def require_status!(response, expected, step)
  return if response.code.to_i == expected

  fail_step!(step, "HTTP #{response.code} (expected #{expected})")
end

begin
  health = request(:get, "/health")
  require_status!(health, 200, "health")
  fail_step!("health", "unexpected response body") unless health.body.strip == "ok"
  progress("health: HTTP 200, body ok")

  session = request(
    :post,
    "/v1/session/fallback",
    headers: {
      "Content-Type" => "application/json",
      "X-RideHorizon-Device-Id" => SecureRandom.uuid
    },
    body: {}
  )
  require_status!(session, 200, "session")
  session_payload = parse_json!(session, "session")
  token = session_payload.fetch("sessionToken")
  fail_step!("session", "token entropy check failed") if token.bytesize < 32
  fail_step!("session", "fallback marker missing") unless session_payload["fallback"] == true
  progress("session: HTTP 200, restricted fallback session issued")

  authorization = { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" }

  fact = request(
    :post,
    "/v1/fact",
    headers: authorization,
    body: {
      boundary: "town",
      placeName: "Stroud",
      factMode: "shortFacts",
      countryContext: "United Kingdom",
      placeHierarchy: {
        town: "Stroud",
        county: "Gloucestershire",
        region: "England",
        country: "United Kingdom"
      },
      riderContext: {
        factInterestCategories: ["geographyBasics", "locationFacts", "history"]
      }
    }
  )
  require_status!(fact, 200, "fact")
  fact_payload = parse_json!(fact, "fact")
  fact_length = fact_payload.fetch("fact").to_s.length
  fail_step!("fact", "empty fact") if fact_length.zero?
  progress("fact: HTTP 200, application/json, #{fact_length} characters")

  speech = request(
    :post,
    "/v1/speech",
    headers: authorization,
    body: { text: "RideHorizon live proxy verification." }
  )
  require_status!(speech, 200, "speech")
  content_type = speech["Content-Type"].to_s.split(";").first
  fail_step!("speech", "unexpected content type") unless content_type == "audio/mpeg"
  fail_step!("speech", "returned too little audio") if speech.body.bytesize < 1_000
  progress("speech: HTTP 200, audio/mpeg, #{speech.body.bytesize} bytes")
rescue KeyError
  fail_step!("response", "required field missing")
rescue SocketError, SystemCallError, IOError, Timeout::Error => error
  fail_step!("request", "network failure (#{error.class})")
end
