# Inference

## Serving Surface

The repo serves a real GPU-backed model through vLLM. The inference assets live
under `platform/inference/`:

- `vllm-openai.yaml`: deployment-only vLLM manifest
- `hpa.yaml`: HPA targeting a custom pod metric
- `service.yaml`: stable in-cluster `ClusterIP` service
- `ingress.yaml`: public ALB-backed `/v1` path

The scripts use them intentionally:

- `./scripts/up` installs the public service and ingress but does not start the
  vLLM deployment
- `./scripts/verify` applies only the deployment
- `./scripts/evaluate` applies both the deployment and the HPA

## Current Serving Stack

- image: `vllm/vllm-openai:v0.9.0`
- model: `Qwen/Qwen2.5-0.5B-Instruct`
- served model name: `qwen2.5-0.5b`
- readiness and liveness path: `/health`
- container port: `8000`

Why this is useful for the lab:

- it exercises a real OpenAI-compatible inference surface
- it uses actual GPU scheduling rather than a placeholder sleep workload
- it is small enough to run on the single-GPU instance types allowed by the
  serving `NodePool`s

## Scheduling Contract

The deployment is explicit about where it can run:

- `nodeSelector: workload=gpu`
- `tolerations: gpu=true:NoSchedule`
- `requests.nvidia.com/gpu: 1`
- `limits.nvidia.com/gpu: 1`

That creates the exact control path the repo is meant to test:

1. the pod is created and cannot run on system nodes
2. Karpenter sees pending GPU demand and launches matching capacity
3. the node joins the cluster
4. the NVIDIA device plugin advertises `nvidia.com/gpu`
5. the pod starts, loads the model, and becomes Ready

## Public Inference Edge

The external request path is:

```text
Client -> ALB -> Ingress (/v1) -> Service -> vLLM pod
```

The ingress is created during `./scripts/up`, so the public edge exists before
GPU workloads are launched. That makes `./scripts/verify` a true cold-start test
of the serving workload instead of a mixed infrastructure bootstrap.

## Autoscaling Contract Today

The current HPA in `platform/inference/hpa.yaml`:

- scales the `vllm-openai` deployment
- keeps `minReplicas: 1`
- caps at `maxReplicas: 2`
- uses the custom pod metric `vllm_requests_running`
- targets an average value of `128`

This is enough to prove a working control loop, but it is not yet the ideal
signal. `vllm_requests_running` tracks admitted work, so it can lag behind
queue buildup during bursty traffic.

## Why `warm-1` Exists

The `warm-1` profile applies `platform/tests/gpu-warm-placeholder.yaml` before
starting the real deployment. That tiny deployment:

- selects serving GPU labels
- tolerates the GPU taint
- pins itself to `karpenter.sh/capacity-type=on-demand`
- keeps one serving node alive without consuming the GPU resource

It lets the repo compare:

- zero idle spend with higher cold-start latency
- one warm GPU node with faster first response and higher idle cost

## What The Repo Proves Today

With the scripted path:

```bash
./scripts/up
./scripts/verify
./scripts/evaluate --profile zero-idle
./scripts/evaluate --profile warm-1
```

The repo proves:

- cold-start serving from zero GPU nodes
- public ingress routing to the real inference workload
- HPA-driven scale-out from one to two replicas
- second-node provisioning through Karpenter
- report generation for latency, throughput, utilization, and cost

## Manual Validation

Apply the serving stack yourself:

```bash
kubectl apply -f platform/inference/vllm-openai.yaml
kubectl apply -f platform/inference/hpa.yaml
```

Watch scheduling and autoscaling:

```bash
kubectl get pods -n app -w
kubectl get hpa -n app -w
kubectl get nodeclaims -w
kubectl get nodes -L workload,karpenter.sh/nodepool,karpenter.sh/capacity-type -w
```

Test the public edge:

```bash
EDGE_HOST=$(kubectl get ingress vllm-openai-ingress -n app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl "http://${EDGE_HOST}/v1/completions" \
  -H 'Content-Type: application/json' \
  -d '{"model":"qwen2.5-0.5b","prompt":"Say hello from the public edge.","max_tokens":32,"temperature":0}'
```

## Next Improvement

The next step is not another serving component. It is a better autoscaling
signal. Prometheus already scrapes both waiting and running request metrics; the
project should next promote a capacity-aware pressure metric such as
`waiting + running` into the HPA and compare it against the current
`vllm_requests_running` policy.
