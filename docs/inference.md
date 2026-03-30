# Inference

## Current state

The repository now includes a **real GPU inference service** instead of a
placeholder GPU pod.

What is in place:

- a Karpenter-managed GPU `NodePool`
- the NVIDIA device plugin
- a real vLLM deployment at `platform/inference/vllm-openai.yaml`
- a `ClusterIP` service that exposes an OpenAI-compatible API
- an HPA and a load-test job that can drive scale-out

## Serving stack

The current serving runtime is:

- image: `vllm/vllm-openai:v0.9.0`
- model: `Qwen/Qwen2.5-0.5B-Instruct`
- served model name: `qwen2.5-0.5b`

Why this stack:

- vLLM is representative of current GPU LLM serving patterns
- it exposes a stable HTTP API instead of a shell command or sleep loop
- the model is small enough to fit on the single-GPU node types used in this lab

## Scheduling contract

The deployment depends on the same explicit scheduling rules the rest of the
platform is built around:

- `nodeSelector: workload=gpu`
- `gpu=true:NoSchedule` toleration
- `requests.nvidia.com/gpu: 1`
- `limits.nvidia.com/gpu: 1`

That means the workload will stay pending until:

1. Karpenter creates a matching `NodeClaim`
2. the EC2 GPU node joins the cluster
3. the NVIDIA device plugin advertises `nvidia.com/gpu`

## Manual validation

Apply the serving manifest:

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

## Load-triggered scale-out

Apply the checked-in load test:

```bash
kubectl apply -f platform/tests/gpu-load-test.yaml
```

The checked-in k6 job is intentionally a little aggressive because the demo model
is small and the HPA scales on CPU utilization.

Then watch:

```bash
kubectl get hpa -n app -w
kubectl get pods -n app -w
kubectl get nodeclaims -w
```

When the HPA requests a second replica, Karpenter should provision a second GPU
node because each vLLM pod requests one full GPU.

## Scale-down behavior

Delete the load test:

```bash
kubectl delete -f platform/tests/gpu-load-test.yaml
```

After the HPA settles back to one replica and the extra node empties, Karpenter
should terminate the second GPU node. Deleting the inference manifest should
return the cluster to zero GPU nodes.
