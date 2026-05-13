# FP4 Quantization Optimization Results

No curated live-cluster run has been recorded yet.

## Live Attempt Log

| Date | Attempt | Outcome |
| --- | --- | --- |
| 2026-05-13 | Plain NVFP4 quantization job on `p6-b200.48xlarge` in `us-west-2b/us-west-2d`, then retried with an added Karpenter-discovered `us-west-2a` private subnet | Blocked by EC2 `UnfulfillableCapacity` for `p6-b200.48xlarge`; no B200 node launched, no quantized artifact was produced, and the stack was torn down |

## Planned Comparison

| Profile | Method | Artifact | Serving cost/hr | Build cost | Result status |
| --- | --- | --- | ---: | ---: | --- |
| `bf16-baseline` | `bf16` | `Qwen/Qwen2.5-7B-Instruct` | 82.368 | 0.000000 | pending |
| `nvfp4-plain` | `nvfp4` | `/models/qwen25-7b-nvfp4-plain` | 82.368 | 82.368000 | pending |
| `nvfp4-smoothquant` | `nvfp4+smoothquant` | `/models/qwen25-7b-nvfp4-smoothquant` | 82.368 | 123.552000 | pending |

## Result Template

| Metric | `bf16-baseline` | `nvfp4-plain` | `nvfp4-smoothquant` |
| --- | ---: | ---: | ---: |
| GPU memory used GiB | pending | pending | pending |
| Memory reduction vs BF16 | pending | pending | pending |
| p95 request latency seconds | pending | pending | pending |
| p99 request latency seconds | pending | pending | pending |
| Requests/sec | pending | pending | pending |
| Generated tokens/sec | pending | pending | pending |
| `arc_easy` score | pending | pending | pending |
| `hellaswag` score | pending | pending | pending |
| `winogrande` score | pending | pending | pending |
| Average accuracy score | pending | pending | pending |
| FP4 recovery vs BF16 | n/a | pending | pending |
| SmoothQuant gain vs plain NVFP4 | n/a | n/a | pending |
| Estimated serving cost USD | pending | pending | pending |
| Cost per 1K successful requests USD | pending | pending | pending |
| Cost per 1M generated tokens USD | pending | pending | pending |
| Cost per accuracy point USD | pending | pending | pending |
| Cost per accuracy recovered percent USD | n/a | pending | pending |
| Quantization build cost USD | 0.000000 | 82.368000 | 123.552000 |

## Interpretation Template

Summarize whether SmoothQuant improves NVFP4 accuracy recovery. Keep recurring
serving cost and one-time quantization build cost separate, and call out any
latency or throughput regressions that erase the memory benefit.
