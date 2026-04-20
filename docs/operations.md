# Operations

Use [dev-environment.md](dev-environment.md) for the full walkthrough. This
page is the short operator summary for choosing the right path and reading the
results.

## Choose The Right Workflow

| Command | Use it when | What it proves |
| --- | --- | --- |
| `./scripts/up` | you need the platform online | cluster, controllers, observability, Karpenter, GPU prerequisites, and public edge are ready |
| `./scripts/verify` | you want the fastest end-to-end validation | cold-start from zero GPU nodes, first Ready replica, first successful public completion, cleanup back to zero |
| `./scripts/evaluate --profile zero-idle` | you want the original baseline experiment | running-request HPA from a true zero-GPU baseline |
| `./scripts/evaluate --profile zero-idle --policy active-pressure --active-target 4` | you want the capacity-aware experiment directly | active-pressure HPA from the same zero-GPU baseline |
| `./scripts/evaluate --profile zero-idle --resilience spot-unavailable` | you want the first degraded-capacity experiment | spot burst capacity is withdrawn, on-demand fallback is measured, and the report records the fallback outcome plus zones |
| `./scripts/evaluate --profile warm-1 --policy compare --active-target 6` | you want the most informative operator readout | sequential running versus active-pressure comparison with one warm on-demand serving node |
| `./scripts/evaluate --profile zero-idle --policy sweep --active-targets 2,4,6,8` | you want to tune active-pressure capacity instead of just proving it exists | per-target active-pressure experiments plus a recommendation summary |
| `./scripts/down` | you want a clean teardown | runtime surface, observability, capacity definitions, and Terraform infrastructure are removed |
| `./scripts/down --cleanup-orphan-enis` | a destroy dependency failure left behind `available` `aws-K8S` ENIs | `scripts/down` deletes cleanup-eligible orphan CNI ENIs, retries `terraform destroy` once, and still leaves non-matching ENIs for manual review |

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
- single-policy runs wrote `evaluate-<profile>-<policy>-<timestamp>.md` and
  `.json`
- compare runs wrote the two per-policy artifacts plus a compare summary report
- sweep runs wrote one per-target report pair plus a sweep summary report
- degraded-capacity runs also recorded the resilience mode, fallback outcome,
  and GPU availability zones
- the overall workflow returned profile-specific warm capacity to zero GPU nodes

## Questions This Repo Can Answer Today

- Can the public inference edge come up cleanly after cluster bootstrap?
- Can a pending GPU workload trigger Karpenter provisioning?
- How long does the first GPU node take to appear?
- How long does the first pod take to become Ready?
- How does `vllm_requests_running` compare with
  `vllm_requests_active = waiting + running` as the HPA signal?
- Which `--active-target` looks healthiest for this burst shape before latency,
  queue pressure, or GPU saturation turn ugly?
- Does scale-out trigger a second serving node?
- What do p95 latency, estimated queue wait, TTFT, peak waiting requests, peak
  active requests, throughput, and GPU utilization look like during a
  controlled burst?
- What do you gain or pay by keeping one warm GPU node around?
- What happens when the preferred spot burst path is unavailable before the
  burst starts?

## Observability And Artifacts

The scripted workflow ships with:

- Prometheus metrics for vLLM request latency, queue depth, request concurrency,
  and token throughput
- Grafana dashboards for serving behavior, capacity shape, and experiment
  summaries
- DCGM exporter metrics for GPU utilization
- `docs/reports/*.md` and `docs/reports/*.json` outputs from
  `./scripts/evaluate`
- Pushgateway experiment metrics labeled by `profile`, `resilience`, `policy`,
  and target

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

The repo now compares both autoscaling policies, but the control loop is still
intentionally simple:

- queue reporting is derived from waiting depth over request completion rate,
  not a dedicated queue-wait histogram
- the sweep recommendation is still heuristic rather than backed by a dedicated
  queue histogram or full per-GPU capacity model
- the new resilience path simulates spot scarcity before the burst; it does not
  yet inject a live spot interruption after the second node is already serving

## Dev Boundary

The dev environment keeps the EKS API public for convenience. That is not the
production answer.

Production direction:

- private cluster endpoint access
- SSM, bastion, or VPN-based admin access
- narrower public-access CIDR ranges
