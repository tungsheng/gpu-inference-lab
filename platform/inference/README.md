# platform/inference

This directory contains the manifests for the public inference surface:

- `vllm-openai.yaml`: GPU-bound vLLM deployment
- `hpa.yaml`: running-request HPA baseline
- `hpa-active-pressure.yaml`: active-pressure HPA baseline
- `model-artifacts-pvc.yaml`: optional artifact storage for locally quantized
  model outputs
- `service.yaml`: stable in-cluster `ClusterIP` service
- `ingress.yaml.tpl`: ALB-backed `/v1` route, rendered at apply time with an
  explicit source range (see [Edge Exposure](#edge-exposure))
- `versions.env`: the single source of truth for every vLLM image this lab runs

## Current Behavior

The deployment uses:

- image `VLLM_IMAGE_DEFAULT` from `versions.env` (currently
  `vllm/vllm-openai:v0.9.0`)
- model `Qwen/Qwen2.5-0.5B-Instruct`
- served model name `qwen2.5-0.5b`
- one requested and limited GPU per replica

A `startupProbe` owns the cold-start budget (620s) so image pull and model load
cannot trip the liveness probe and crash-loop the pod. Readiness and liveness
only begin counting once the startup probe succeeds.

The scripts consume these manifests in different ways:

- `./scripts/up` applies only the service and rendered ingress so the edge exists
  before any GPU pod is launched
- `./scripts/verify` applies the deployment only to prove the cold-start path
- `./scripts/evaluate` applies the deployment plus the selected HPA policy to
  prove burst scale-out, runs both policies sequentially in compare mode, or
  sweeps active-pressure targets

## Serving Images

`versions.env` declares every vLLM image the lab runs:

| Name | Purpose |
| --- | --- |
| `VLLM_IMAGE_DEFAULT` | legacy baseline; the engine behind the curated evidence in `experiments/*/evidence/` |
| `VLLM_IMAGE_MODERN` | current target for new KV-cache observatory work |
| `VLLM_IMAGE_BLACKWELL` | Blackwell / NVFP4 quantization path |

Serving-profile CSVs reference these symbolically and the reference is expanded
when the profile is loaded:

```csv
modern-vllm-0221,,,@VLLM_IMAGE_MODERN@,9216,0.90,32,9216,,,,,,,modern vLLM profile
```

`vllm-openai.yaml` still pins a concrete tag because `./scripts/up`,
`./scripts/verify`, and `./scripts/evaluate` apply it directly. Rather than
template it, `./scripts/experiment validate` fails if that tag and the default
profile stop matching `VLLM_IMAGE_DEFAULT`, so the two cannot drift apart
unnoticed.

Changing a value in `versions.env` changes the engine future runs measure.
Evidence already curated under a previous engine keeps its recorded image and is
not rewritten; see `experiments/kv-cache-observatory/experiment.yaml`.

## Edge Exposure

The ingress is a template, not an applyable manifest. `./scripts/up` and
`./scripts/evaluate` render it through `apply_inference_ingress`, which requires
an explicit source range and refuses to create the listener without one.

| Variable | Default | Meaning |
| --- | --- | --- |
| `GPU_INFERENCE_INBOUND_CIDRS` | `auto` | `auto` restricts the ALB to this machine public IP; otherwise a comma-separated list of CIDRs or bare IPv4 addresses |
| `GPU_INFERENCE_INGRESS_SCHEME` | `internet-facing` | `internet-facing` or `internal` |

```bash
# default: reachable only from the machine that ran ./scripts/up
./scripts/up

# a fixed office range
GPU_INFERENCE_INBOUND_CIDRS=203.0.113.0/24 ./scripts/up
```

`0.0.0.0/0` is still accepted, but only when written out explicitly, and the
render prints a warning: the endpoint serves an unauthenticated
OpenAI-compatible API over plain HTTP. An empty value is an error rather than a
fallback, so a blank override can never widen the edge. A failed `auto` lookup
fails the render instead of falling back to an open listener.

## Scheduling Contract

The deployment is intentionally strict:

- `nodeSelector: workload=gpu`
- GPU taint toleration
- `nvidia.com/gpu: 1`

That forces the pod onto Karpenter-managed GPU capacity instead of allowing it
to land on system nodes.

Profiles that serve local artifact paths under `/models/` mount the
`model-artifacts` PVC. The FP4 quantization jobs write NVFP4 artifacts there,
and the matching serving manifests read those artifacts back from the same
mount.

## Autoscaling Today

The HPA depends on the observability stack because both policies read custom pod
metrics from Prometheus Adapter:

- `hpa.yaml` uses `vllm_requests_running`
- `hpa-active-pressure.yaml` uses `vllm_requests_active = waiting + running`

That is the current repo truth:

- it proves the custom-metrics control loop works with two signals
- it lets `./scripts/evaluate --policy compare` compare those signals directly
- it lets `./scripts/evaluate --policy sweep` calibrate active-pressure targets
