# Inference

## Current State

The repository includes a real GPU inference service instead of a placeholder
GPU pod.

What is in place by default:

- a Karpenter-managed GPU `NodePool`
- the NVIDIA device plugin
- a deployment-only vLLM manifest at `platform/inference/vllm-openai.yaml`
- a dedicated `ClusterIP` service at `platform/inference/service.yaml`
- a public ALB ingress at `platform/inference/ingress.yaml`

Optional extras stay separate:

- `platform/inference/hpa.yaml` for autoscaling
- `platform/tests/gpu-load-test.yaml` for load-driven scale-out experiments
- `platform/observability/` for the metrics stack that supports the HPA

## Serving Stack

- image: `vllm/vllm-openai:v0.9.0`
- model: `Qwen/Qwen2.5-0.5B-Instruct`
- served model name: `qwen2.5-0.5b`

Why this stack:

- vLLM is representative of current GPU LLM serving patterns
- it exposes a stable HTTP API instead of a shell command or sleep loop
- the model is small enough to fit on the single-GPU node types used in this lab

## Scheduling Contract

The deployment depends on the same explicit scheduling rules the rest of the
platform is built around:

- `nodeSelector: workload=gpu`
- `gpu=true:NoSchedule` toleration
- `requests.nvidia.com/gpu: 1`
- `limits.nvidia.com/gpu: 1`

That means the workload stays pending until:

1. Karpenter creates matching capacity
2. the EC2 GPU node joins the cluster
3. the NVIDIA device plugin advertises `nvidia.com/gpu`

## Default Validation

Use the scripted path:

```bash
./scripts/up
./scripts/verify
```

`./scripts/verify` is the default proof that the public inference edge works.

## Manual Validation

Apply the serving deployment manually:

```bash
kubectl apply -f platform/inference/vllm-openai.yaml
```

Watch scheduling:

```bash
kubectl get pods -n app -w
kubectl get nodeclaims -w
kubectl get nodes -L workload,node.kubernetes.io/instance-type -w
```

Once the pod is Ready, test the API from inside the cluster:

```bash
kubectl run curl -n app --rm -it --restart=Never \
  --image=curlimages/curl:8.8.0 -- \
  curl http://vllm-openai/v1/completions \
    -H 'Content-Type: application/json' \
    -d '{"model":"qwen2.5-0.5b","prompt":"Say hello from vLLM.","max_tokens":32,"temperature":0}'
```

If the public ingress is already provisioned, you can also test the external
edge from your machine:

```bash
EDGE_HOST=$(kubectl get ingress vllm-openai-ingress -n app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl "http://${EDGE_HOST}/v1/completions" \
  -H 'Content-Type: application/json' \
  -d '{"model":"qwen2.5-0.5b","prompt":"Say hello from the public edge.","max_tokens":32,"temperature":0}'
```
