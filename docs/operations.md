# Operations

Use [dev-environment.md](dev-environment.md) for the full walkthrough. This
page is the short operator summary for choosing the right path and reading the
results.

## Choose The Right Workflow

| Command | Use it when | What it proves |
| --- | --- | --- |
| `./scripts/up` | you need the platform online | cluster, controllers, observability, Karpenter, GPU prerequisites, and public edge are ready |
| `./scripts/verify` | you want the fastest end-to-end validation | cold-start from zero GPU nodes, first Ready replica, first successful public completion, cleanup back to zero |
| `./scripts/evaluate --profile zero-idle` | you want the lowest-idle-cost burst experiment | HPA-driven scale-out from a true zero-GPU baseline |
| `./scripts/evaluate --profile warm-1` | you want to compare latency against a warm baseline | same burst experiment with one on-demand serving node already present |
| `./scripts/down` | you want a clean teardown | runtime surface, observability, capacity definitions, and Terraform infrastructure are removed |

## Expected States

After `./scripts/up`:

- ingress hostname exists
- Prometheus Adapter is Available
- Karpenter is Ready
- GPU node count is `0`

After `./scripts/verify`:

- one GPU node was provisioned during the run
- one vLLM replica became Ready
- the public `/v1/completions` edge returned `200`
- GPU node count returned to `0`

After `./scripts/evaluate`:

- one burst caused the HPA to scale from `1` to `2`
- a second serving `NodeClaim` and second GPU node appeared
- Markdown and JSON reports were written under `docs/reports/`
- profile-specific warm capacity was cleaned up

## Questions This Repo Can Answer Today

- Can the public inference edge come up cleanly after cluster bootstrap?
- Can a pending GPU workload trigger Karpenter provisioning?
- How long does the first GPU node take to appear?
- How long does the first pod take to become Ready?
- Can `vllm_requests_running` drive HPA scale-out?
- Does scale-out trigger a second serving node?
- What do p95 latency, TTFT, throughput, and GPU utilization look like during a
  controlled burst?
- What do you gain or pay by keeping one warm GPU node around?

## Observability And Artifacts

The scripted workflow ships with:

- Prometheus metrics for vLLM request latency, queue depth, request concurrency,
  and token throughput
- Grafana dashboards for serving behavior, capacity shape, and experiment
  summaries
- DCGM exporter metrics for GPU utilization
- `docs/reports/*.md` and `docs/reports/*.json` outputs from
  `./scripts/evaluate`

## What To Watch During A Run

Useful commands while the scripts are running:

```bash
kubectl get pods -n app -w
kubectl get hpa -n app -w
kubectl get nodeclaims -w
kubectl get nodes -L workload,karpenter.sh/nodepool,karpenter.sh/capacity-type -w
```

For dashboard access:

```bash
kubectl port-forward -n monitoring deployment/kube-prometheus-stack-grafana 3000:3000
```

## Current Limitation

The current HPA uses `vllm_requests_running`. That is good enough to prove a
working scale-out loop, but it scales from admitted work instead of total
pressure. Queue buildup is visible in Prometheus and Grafana today, yet it is
not the primary autoscaling signal. The roadmap moves next toward a
capacity-aware metric such as `waiting + running`.

## Dev Boundary

The dev environment keeps the EKS API public for convenience. That is not the
production answer.

Production direction:

- private cluster endpoint access
- SSM, bastion, or VPN-based admin access
- narrower public-access CIDR ranges
