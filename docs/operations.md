# Operations

This is the command chooser. Use [dev-environment.md](dev-environment.md) when
you need the full setup and teardown walkthrough.

## Choose A Workflow

| Command | Use it when | Expected result |
| --- | --- | --- |
| `./scripts/experiment list` | you want to inspect local experiment definitions | prints the experiment catalog |
| `./scripts/experiment validate` | you changed experiment CSVs, profiles, or templates | validates catalog contracts without AWS |
| `./scripts/experiment render-load|render-stream|render-serving|render-report ...` | you want generated manifests or empty report scaffolds | renders local artifacts only; no workload runs and no cluster metrics are collected |
| `./scripts/experiment run ...` | you want to execute one measured experiment case | requires a live cluster from `./scripts/up`, applies rendered manifests, waits for the load job, and writes measured reports |
| `./scripts/experiment run-stream ...` | you want to execute one measured streaming case | requires a live cluster from `./scripts/up`, runs the streaming client, and writes measured TTFT/inter-token reports |
| `./scripts/up` | you need the dev platform online | Terraform, controllers, observability, Karpenter, GPU prerequisites, service, and ingress are ready |
| `./scripts/verify` | you want the fastest end-to-end proof | one GPU node appears, vLLM becomes Ready, `/v1/completions` returns `200`, then GPU nodes return to zero |
| `./scripts/evaluate --profile zero-idle` | you want the default burst baseline | running-request HPA scales from a true zero-GPU baseline |
| `./scripts/evaluate --profile zero-idle --policy active-pressure --active-target 4` | you want the active-pressure policy directly | HPA scales on `waiting + running` pressure |
| `./scripts/evaluate --profile warm-1 --policy compare --active-target 6` | you want the clearest operator comparison | running and active-pressure policies run sequentially against one warm on-demand serving node |
| `./scripts/evaluate --profile warm-1 --policy compare --compare-order active-pressure,running --active-target 6` | you want to check whether compare ordering affected the result | active-pressure and running policies run in the reverse order against the same warm profile |
| `./scripts/evaluate --profile zero-idle --policy sweep --active-targets 2,4,6,8` | you want to calibrate active-pressure targets | one report pair per target plus a sweep summary |
| `./scripts/evaluate --profile zero-idle --resilience spot-unavailable` | you want pre-run degraded-capacity evidence | spot burst capacity is withdrawn and on-demand fallback is measured |
| `./scripts/evaluate --profile zero-idle --resilience spot-interruption` | you want a synthetic interruption drill | a live spot-backed burst node is deleted and replacement timing is reported |
| `./scripts/down` | you want a normal teardown | runtime resources, controllers, observability, capacity definitions, and Terraform infrastructure are removed |
| `./scripts/down --cleanup-orphan-enis` | destroy failed because cleanup-eligible CNI ENIs remain | matching `available` `aws-K8S` or `aws-node` ENIs are deleted, then destroy is retried once |
| `./scripts/down --terraform-only` | the cluster API is already gone or cluster-scoped cleanup already completed | Kubernetes, Helm, and AWS cleanup are skipped; Terraform init/destroy still run |

## Expected States

After `./scripts/up`:

- ingress hostname exists
- Prometheus Adapter is Available
- Karpenter is Ready
- total GPU node count is `0`

After `./scripts/verify`:

- one GPU node was provisioned during the run
- one vLLM replica became Ready
- the public `/v1/completions` edge returned `200`
- GPU node count returned to `0`

After `./scripts/evaluate`:

- the selected HPA policy was applied
- burst load ran through the checked-in k6 job
- scale-out to two replicas and two serving GPU nodes was observed when the run
  reached the expected pressure
- Markdown and JSON reports were written under `docs/reports/`
- final metric collection failures were recorded as `partial` reports instead
  of discarding completed timeline data
- profile-specific warm capacity was cleaned up at the end

## What To Watch

Useful commands while a live run is in progress:

```bash
kubectl get pods -n app -w
kubectl get hpa -n app -w
kubectl get nodeclaims -w
kubectl get nodes -L workload,karpenter.sh/nodepool,karpenter.sh/capacity-type -w
```

Grafana access:

```bash
kubectl port-forward -n monitoring deployment/kube-prometheus-stack-grafana 3000:3000
```

## Current Limits

- queue wait is derived from waiting depth over request completion rate, not a
  dedicated queue-wait histogram
- active-pressure sweep recommendations are heuristic
- current local reports support platform-validation claims, not GPU-utilization,
  KV-cache, batching, or target-optimization conclusions
- final Prometheus/DCGM reads are best-effort after workload cleanup
- spot interruption is synthetic `NodeClaim` deletion, not a cloud-native
  interruption notice
- the dev EKS API is public for iteration; production should use private
  control-plane access and tighter operator access controls
