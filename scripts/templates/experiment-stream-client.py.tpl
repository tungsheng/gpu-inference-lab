import json
import math
import concurrent.futures
import random
import sys
import time
import urllib.error
import urllib.request

experiment_name = "@EXPERIMENT_NAME@"
case_id = "@CASE_ID@"
prompt_token_target = @PROMPT_TOKEN_TARGET@
max_tokens = @MAX_TOKENS@
request_shapes = @REQUEST_SHAPES_JSON@
samples = @SAMPLES@
stream_concurrency = @STREAM_CONCURRENCY@
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

def optional_float(value):
  return None if value == "" else float(value)

def average(values):
  if not values:
    return None
  return sum(values) / len(values)

def display_metric(value):
  return "n/a" if value is None else f"{value:.6f}"

def select_request_shape():
  total_weight = sum(shape["weight"] for shape in request_shapes)
  threshold = random.random() * total_weight
  for shape in request_shapes:
    threshold -= shape["weight"]
    if threshold <= 0:
      return shape
  return request_shapes[-1]

def stream_once(request_shape):
  payload = json.dumps({
    "model": model_name,
    "prompt": build_prompt(request_shape["prompt_token_target"]),
    "max_tokens": request_shape["max_tokens"],
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

shape_stats = {
  shape["id"]: {
    "shape": shape,
    "completed_requests": 0,
    "failed_requests": 0,
    "request_latencies": [],
    "ttfts": [],
    "inter_token_latencies": [],
    "chunk_rates": [],
  }
  for shape in request_shapes
}
request_latencies = []
ttfts = []
inter_token_latencies = []
chunk_rates = []
failed_requests = 0
run_start = time.perf_counter()

with concurrent.futures.ThreadPoolExecutor(max_workers=stream_concurrency) as executor:
  future_shapes = {}
  for _ in range(samples):
    request_shape = select_request_shape()
    future_shapes[executor.submit(stream_once, request_shape)] = request_shape

  for future in concurrent.futures.as_completed(future_shapes):
    request_shape = future_shapes[future]
    shape_stat = shape_stats[request_shape["id"]]
    try:
      result = future.result()
    except (urllib.error.URLError, TimeoutError, OSError) as exc:
      failed_requests += 1
      shape_stat["failed_requests"] += 1
      sys.stderr.write(f"stream request failed: {exc}\n")
      continue

    shape_stat["completed_requests"] += 1
    shape_stat["request_latencies"].append(result["total_latency"])
    request_latencies.append(result["total_latency"])
    if result["ttft"] != "":
      shape_stat["ttfts"].append(result["ttft"])
      ttfts.append(result["ttft"])
    shape_stat["inter_token_latencies"].extend(result["inter_token_latencies"])
    inter_token_latencies.extend(result["inter_token_latencies"])
    if result["chunks_per_second"] != "":
      shape_stat["chunk_rates"].append(result["chunks_per_second"])
      chunk_rates.append(result["chunks_per_second"])

run_duration_seconds = time.perf_counter() - run_start
completed_requests = len(request_latencies)
average_chunk_rate = "" if not chunk_rates else sum(chunk_rates) / len(chunk_rates)
shape_summaries = []

for request_shape in request_shapes:
  shape_stat = shape_stats[request_shape["id"]]
  shape_summaries.append({
    "id": request_shape["id"],
    "prompt_token_target": request_shape["prompt_token_target"],
    "max_tokens": request_shape["max_tokens"],
    "weight": request_shape["weight"],
    "completed_requests": shape_stat["completed_requests"],
    "failed_requests": shape_stat["failed_requests"],
    "p50_request_latency_seconds": optional_float(percentile(shape_stat["request_latencies"], 50)),
    "p95_request_latency_seconds": optional_float(percentile(shape_stat["request_latencies"], 95)),
    "p99_request_latency_seconds": optional_float(percentile(shape_stat["request_latencies"], 99)),
    "p50_ttft_seconds": optional_float(percentile(shape_stat["ttfts"], 50)),
    "p95_ttft_seconds": optional_float(percentile(shape_stat["ttfts"], 95)),
    "p50_inter_token_latency_seconds": optional_float(percentile(shape_stat["inter_token_latencies"], 50)),
    "p95_inter_token_latency_seconds": optional_float(percentile(shape_stat["inter_token_latencies"], 95)),
    "generation_tokens_per_second": average(shape_stat["chunk_rates"]),
  })

print("GPU_LAB_STREAM_SUMMARY_BEGIN")
print(f"stream_samples={samples}")
print(f"stream_concurrency={stream_concurrency}")
print("stream_shape_summaries=" + json.dumps(shape_summaries, separators=(",", ":")))
for shape_summary in shape_summaries:
  print(
    "stream_shape_summary_row="
    f"| {shape_summary['id']} "
    f"| {shape_summary['prompt_token_target']} "
    f"| {shape_summary['max_tokens']} "
    f"| {shape_summary['completed_requests']} "
    f"| {shape_summary['failed_requests']} "
    f"| {display_metric(shape_summary['p95_request_latency_seconds'])} "
    f"| {display_metric(shape_summary['p95_ttft_seconds'])} "
    f"| {display_metric(shape_summary['p95_inter_token_latency_seconds'])} "
    f"| {display_metric(shape_summary['generation_tokens_per_second'])} |"
  )
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
