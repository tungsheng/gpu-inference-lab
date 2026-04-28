# KV Cache Vs Concurrency

## Goal

Show that longer prompts reduce stable concurrency because each active sequence
requires more KV-cache memory.

## Cases

| Case | Prompt token target | Output token cap | Initial target rate |
| --- | ---: | ---: | ---: |
| `prompt-512-output-100` | 512 | 100 | 6 req/s |
| `prompt-2048-output-200` | 2048 | 200 | 4 req/s |
| `prompt-8192-output-300` | 8192 | 300 | 2 req/s |

The prompt generator currently builds approximate token targets from repeated
English words. A later slice should add tokenizer-backed prompt construction
when exact model-token counts are required.

## Render A Load Job

```bash
./scripts/experiment render-load \
  --experiment kv-cache \
  --case prompt-512-output-100 \
  --output /tmp/kv-cache-prompt-512-output-100.yaml
```

Apply the rendered job only after the serving deployment and HPA policy are
ready:

```bash
kubectl apply -f /tmp/kv-cache-prompt-512-output-100.yaml
```

## Render A Serving Profile

The `default` profile mirrors the checked-in vLLM manifest used by
`./scripts/verify` and `./scripts/evaluate`:

```bash
./scripts/experiment render-serving \
  --experiment kv-cache \
  --profile default \
  --output /tmp/vllm-default.yaml
```

The long-context profile raises `--max-model-len` to `8192` and adds explicit
vLLM scheduler limits for the 8K prompt case:

```bash
./scripts/experiment render-serving \
  --experiment kv-cache \
  --profile long-context \
  --output /tmp/vllm-long-context.yaml
```

## Render A Report Scaffold

Before a live runner exists, use `render-report` to create a consistent
Markdown/JSON result shell for a specific workload and serving profile. The
configuration fields are populated immediately; measured results stay `n/a` in
Markdown and `null` in JSON until a live cluster run fills them.

```bash
./scripts/experiment render-report \
  --experiment kv-cache \
  --case prompt-8192-output-300 \
  --profile long-context
```

## Run One Case On A Live Cluster

`run` requires a configured Kubernetes context and a live cluster from
`./scripts/up`. It validates that the selected serving profile can fit the
case's prompt plus output token budget, applies the rendered service, serving
deployment, and k6 load job, waits for the job to complete, parses the k6
summary, writes Markdown/JSON reports, stores the k6 log next to the JSON
report, and cleans up the rendered load and serving resources by default.

```bash
./scripts/up

./scripts/experiment run \
  --experiment kv-cache \
  --case prompt-512-output-100 \
  --profile default
```

Use the long-context profile for cases whose prompt plus output budget exceeds
the default 2048-token model length:

```bash
./scripts/experiment run \
  --experiment kv-cache \
  --case prompt-8192-output-300 \
  --profile long-context
```

Add `--preserve-serving` if you are running multiple cases and want to keep the
rendered vLLM deployment alive between runs. Remember to clean it up afterward
to avoid idle GPU spend.

## Metrics To Capture

- max stable concurrency before request failures or OOM
- GPU memory used and free
- p95 and p99 end-to-end latency
- completed requests/sec
- generated tokens/sec
- GPU utilization
- request failures and OOM events

## Expected Interpretation

The result should explain how increasing prompt length increases KV-cache
pressure, lowers the number of active sequences a GPU can hold, and changes the
latency/throughput envelope.
