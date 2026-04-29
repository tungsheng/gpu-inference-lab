import json
import math
import sys
import time
import urllib.error
import urllib.request

experiment_name = "@EXPERIMENT_NAME@"
case_id = "@CASE_ID@"
prompt_token_target = @PROMPT_TOKEN_TARGET@
max_tokens = @MAX_TOKENS@
samples = @SAMPLES@
timeout_seconds = @TIMEOUT_SECONDS@
target_url = "@TARGET_URL@"
model_name = "@MODEL_NAME@"

def build_prompt(target_tokens):
  seed_words = [
    "GPU", "inference", "capacity", "planning", "requires", "measuring",
    "KV", "cache", "pressure", "queueing", "latency", "throughput",
    "memory", "headroom", "scheduling", "autoscaling", "recovery",
    "cost", "utilization", "tail", "behavior", "controlled", "workloads",
  ]
  return " ".join(seed_words[index % len(seed_words)] for index in range(target_tokens))

def percentile(values, percentile_value):
  if not values:
    return ""
  sorted_values = sorted(values)
  if len(sorted_values) == 1:
    return f"{sorted_values[0]:.6f}"
  index = (len(sorted_values) - 1) * (percentile_value / 100.0)
  lower = math.floor(index)
  upper = math.ceil(index)
  if lower == upper:
    return f"{sorted_values[int(index)]:.6f}"
  weight = index - lower
  value = sorted_values[lower] * (1 - weight) + sorted_values[upper] * weight
  return f"{value:.6f}"

def stream_once():
  payload = json.dumps({
    "model": model_name,
    "prompt": build_prompt(prompt_token_target),
    "max_tokens": max_tokens,
    "temperature": 0,
    "stream": True,
  }).encode("utf-8")
  request = urllib.request.Request(
    target_url,
    data=payload,
    headers={"Content-Type": "application/json"},
    method="POST",
  )

  start_time = time.perf_counter()
  first_token_time = None
  previous_token_time = None
  inter_token_latencies = []
  output_chunks = 0

  with urllib.request.urlopen(request, timeout=timeout_seconds) as response:
    for raw_line in response:
      line = raw_line.decode("utf-8", errors="replace").strip()
      if not line.startswith("data:"):
        continue
      data = line[5:].strip()
      if data == "[DONE]":
        break
      try:
        chunk = json.loads(data)
      except json.JSONDecodeError:
        continue
      choices = chunk.get("choices", [])
      if not choices:
        continue
      text = choices[0].get("text", "")
      if text == "":
        continue

      now = time.perf_counter()
      if first_token_time is None:
        first_token_time = now
      elif previous_token_time is not None:
        inter_token_latencies.append(now - previous_token_time)
      previous_token_time = now
      output_chunks += 1

  end_time = time.perf_counter()
  total_latency = end_time - start_time
  ttft = "" if first_token_time is None else first_token_time - start_time
  generation_time = max(total_latency - ttft, 0.000001) if ttft != "" else ""
  chunks_per_second = "" if generation_time == "" else output_chunks / generation_time

  return {
    "total_latency": total_latency,
    "ttft": ttft,
    "inter_token_latencies": inter_token_latencies,
    "chunks_per_second": chunks_per_second,
  }

request_latencies = []
ttfts = []
inter_token_latencies = []
chunk_rates = []
failed_requests = 0
run_start = time.perf_counter()

for _ in range(samples):
  try:
    result = stream_once()
  except (urllib.error.URLError, TimeoutError, OSError) as exc:
    failed_requests += 1
    sys.stderr.write(f"stream request failed: {exc}\n")
    continue

  request_latencies.append(result["total_latency"])
  if result["ttft"] != "":
    ttfts.append(result["ttft"])
  inter_token_latencies.extend(result["inter_token_latencies"])
  if result["chunks_per_second"] != "":
    chunk_rates.append(result["chunks_per_second"])

run_duration_seconds = time.perf_counter() - run_start
completed_requests = len(request_latencies)
average_chunk_rate = "" if not chunk_rates else sum(chunk_rates) / len(chunk_rates)

print("GPU_LAB_STREAM_SUMMARY_BEGIN")
print(f"completed_requests={completed_requests}")
print(f"failed_requests={failed_requests}")
print(f"p50_request_latency_seconds={percentile(request_latencies, 50)}")
print(f"p95_request_latency_seconds={percentile(request_latencies, 95)}")
print(f"p99_request_latency_seconds={percentile(request_latencies, 99)}")
print(f"p50_ttft_seconds={percentile(ttfts, 50)}")
print(f"p95_ttft_seconds={percentile(ttfts, 95)}")
print(f"p50_inter_token_latency_seconds={percentile(inter_token_latencies, 50)}")
print(f"p95_inter_token_latency_seconds={percentile(inter_token_latencies, 95)}")
print(f"generation_tokens_per_second={average_chunk_rate if average_chunk_rate == '' else f'{average_chunk_rate:.6f}'}")
print(f"run_duration_seconds={run_duration_seconds:.6f}")
print("GPU_LAB_STREAM_SUMMARY_END")
if completed_requests == 0:
  sys.exit(1)
