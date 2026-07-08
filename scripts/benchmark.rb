#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "net/http"
require "time"
require "uri"

TEXTS = [
  "Local-first software keeps private data on the user's own machine.",
  "The extension prioritizes visible headings and main content before sidebars.",
  "Translation caches are useful, but stale entries must be easy to discard.",
  "A local model may be slower than a cloud API, but it avoids sending text away.",
  "Short interface labels often repeat across pages and benefit from caching.",
  "Long articles are split into sentence-level segments before translation.",
  "For reliable comparisons, benchmark the same model with the same prompt.",
  "Measure wall-clock time and throughput, then record the hardware details."
].freeze

def usage!
  warn <<~USAGE
    Usage:
      PROVIDER=ollama MODEL=translategemma TARGET_LANGUAGE=Japanese ruby scripts/benchmark.rb

    Environment:
      PROVIDER         auto, ollama, lmstudio, or llamacpp (default: auto)
      MODEL            model id/name (default: first model returned by provider)
      TARGET_LANGUAGE  translation target language name (default: Japanese)
      SOURCE_LANGUAGE  source language name (default: English)
      BENCH_REPEAT     measured runs after warmup (default: 3)
      BENCH_WARMUP     warmup runs excluded from results (default: 1)
      OLLAMA_URL       default: http://localhost:11434
      LMSTUDIO_URL     default: http://localhost:1234
      LLAMACPP_URL     default: http://localhost:8080
  USAGE
  exit 2
end

def get_json(url, timeout: 5)
  uri = URI(url)
  Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", read_timeout: timeout, open_timeout: timeout) do |http|
    res = http.get(uri.request_uri)
    raise "#{url} returned HTTP #{res.code}" unless res.is_a?(Net::HTTPSuccess)

    JSON.parse(res.body)
  end
end

def post_json(url, payload, timeout: 300)
  uri = URI(url)
  Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", read_timeout: timeout, open_timeout: 10) do |http|
    req = Net::HTTP::Post.new(uri.request_uri)
    req["Content-Type"] = "application/json"
    req.body = JSON.generate(payload)
    res = http.request(req)
    raise "#{url} returned HTTP #{res.code}: #{res.body}" unless res.is_a?(Net::HTTPSuccess)

    JSON.parse(res.body)
  end
end

def detect_provider(provider, ollama_url, lmstudio_url, llamacpp_url)
  return provider unless provider == "auto"

  get_json("#{ollama_url}/api/tags")
  "ollama"
rescue StandardError
  begin
    get_json("#{lmstudio_url}/v1/models")
    "lmstudio"
  rescue StandardError
    begin
      get_json("#{llamacpp_url}/v1/models")
      "llamacpp"
    rescue StandardError
      raise "No provider detected. Start Ollama, LM Studio or llama-server first, or set PROVIDER explicitly."
    end
  end
end

# lmstudio and llamacpp both speak the OpenAI-compatible API (/v1).
def list_models(provider, ollama_url, openai_url)
  if provider == "ollama"
    data = get_json("#{ollama_url}/api/tags")
    data.fetch("models", []).map { |m| m.fetch("name") }
  else
    data = get_json("#{openai_url}/v1/models")
    data.fetch("data", []).map { |m| m.fetch("id") }
  end
end

def translation_prompt(source_language, target_language)
  numbered = TEXTS.each_with_index.map { |text, i| "[#{i}]: #{text}" }.join("\n")
  <<~PROMPT
    You are a professional translator. Translate the following #{source_language} texts to #{target_language}.
    Respond only with JSON in this exact format:
    {"translations":[{"id":0,"text":"translated text"}]}
    Maintain the original meaning and tone.

    #{numbered}
  PROMPT
end

def run_ollama(url, model, prompt)
  post_json("#{url}/api/generate", {
    model: model,
    stream: false,
    prompt: prompt,
    options: { temperature: 0.3 }
  })
end

def run_openai_chat(url, model, prompt)
  post_json("#{url}/v1/chat/completions", {
    model: model,
    stream: false,
    temperature: 0.3,
    messages: [
      { role: "system", content: "You are a professional translator. Output only the requested JSON." },
      { role: "user", content: prompt }
    ]
  })
end

def command_output(*cmd)
  IO.popen(cmd, err: File::NULL, &:read).to_s.strip
rescue StandardError
  ""
end

def cpu_summary
  model = File.read("/proc/cpuinfo")[/^model name\s*:\s*(.+)$/, 1]
  cores = command_output("nproc")
  [model, cores.empty? ? nil : "#{cores} threads"].compact.join(" / ")
rescue StandardError
  "unknown"
end

def ram_summary
  kb = File.read("/proc/meminfo")[/^MemTotal:\s+(\d+) kB$/, 1].to_i
  kb.positive? ? format("%.1f GiB", kb / 1024.0 / 1024.0) : "unknown"
rescue StandardError
  "unknown"
end

def gpu_summary
  smi = command_output("nvidia-smi", "--query-gpu=name,memory.total,driver_version", "--format=csv,noheader")
  return smi unless smi.empty?

  pci = command_output("lspci")
  pci.lines.grep(/VGA|3D|Display/i).map(&:strip).join("; ")
end

provider = ENV.fetch("PROVIDER", "auto")
usage! unless %w[auto ollama lmstudio llamacpp].include?(provider)

ollama_url = ENV.fetch("OLLAMA_URL", "http://localhost:11434")
lmstudio_url = ENV.fetch("LMSTUDIO_URL", "http://localhost:1234")
llamacpp_url = ENV.fetch("LLAMACPP_URL", "http://localhost:8080")
target_language = ENV.fetch("TARGET_LANGUAGE", "Japanese")
source_language = ENV.fetch("SOURCE_LANGUAGE", "English")
repeat = ENV.fetch("BENCH_REPEAT", "3").to_i
warmup = ENV.fetch("BENCH_WARMUP", "1").to_i
usage! if repeat < 1 || warmup < 0

provider = detect_provider(provider, ollama_url, lmstudio_url, llamacpp_url)
openai_url = provider == "llamacpp" ? llamacpp_url : lmstudio_url
models = list_models(provider, ollama_url, openai_url)
model = ENV["MODEL"] || models.first
raise "No model found for #{provider}. Load a model first or set MODEL." if model.to_s.empty?

prompt = translation_prompt(source_language, target_language)
source_chars = TEXTS.sum(&:length)
total_runs = warmup + repeat
results = []

total_runs.times do |i|
  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  response = provider == "ollama" ? run_ollama(ollama_url, model, prompt) : run_openai_chat(openai_url, model, prompt)
  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
  next if i < warmup

  if provider == "ollama"
    text = response["response"].to_s
    eval_count = response["eval_count"].to_i
    eval_duration = response["eval_duration"].to_i
    tokens_per_s = eval_duration.positive? ? eval_count / (eval_duration / 1_000_000_000.0) : nil
  else
    text = response.dig("choices", 0, "message", "content").to_s
    # OpenAI-compatible servers report completion tokens in `usage`; llama-server
    # additionally reports generation speed in its `timings` extension.
    eval_count = response.dig("usage", "completion_tokens")
    tokens_per_s = response.dig("timings", "predicted_per_second")
  end

  results << {
    wall_s: elapsed,
    source_chars_per_s: source_chars / elapsed,
    output_chars: text.length,
    output_tokens: eval_count,
    output_tokens_per_s: tokens_per_s
  }
end

avg = lambda do |key|
  vals = results.map { |r| r[key] }.compact
  vals.empty? ? nil : vals.sum / vals.length.to_f
end

puts "# Local LLM Translation Benchmark"
puts
puts "- Date: #{Time.now.utc.iso8601}"
puts "- Provider: `#{provider}`"
puts "- Model: `#{model}`"
puts "- Source -> target: #{source_language} -> #{target_language}"
puts "- Input: #{TEXTS.length} segments, #{source_chars} source characters"
puts "- Warmup runs: #{warmup}"
puts "- Measured runs: #{repeat}"
puts
puts "## Machine"
puts
puts "- OS: `#{command_output("uname", "-srmo")}`"
puts "- CPU: #{cpu_summary}"
puts "- RAM: #{ram_summary}"
gpu = gpu_summary
puts "- GPU: #{gpu.empty? ? "unknown/not available" : gpu}"
puts
puts "## Results"
puts
puts "| Run | Wall time (s) | Source chars/s | Output chars | Output tokens | Output tokens/s |"
puts "|-----|---------------|----------------|--------------|---------------|-----------------|"
results.each_with_index do |r, i|
  puts "| #{i + 1} | #{format("%.2f", r[:wall_s])} | #{format("%.1f", r[:source_chars_per_s])} | #{r[:output_chars]} | #{r[:output_tokens] || "n/a"} | #{r[:output_tokens_per_s] ? format("%.1f", r[:output_tokens_per_s]) : "n/a"} |"
end
puts "| **Average** | **#{format("%.2f", avg.call(:wall_s))}** | **#{format("%.1f", avg.call(:source_chars_per_s))}** | **#{format("%.0f", avg.call(:output_chars))}** | **#{avg.call(:output_tokens)&.round || "n/a"}** | **#{avg.call(:output_tokens_per_s) ? format("%.1f", avg.call(:output_tokens_per_s)) : "n/a"}** |"
