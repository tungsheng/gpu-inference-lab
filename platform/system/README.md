# platform/system

This directory contains cluster-level runtime prerequisites used by the scripted
workflow.

## Current Manifest

- `nvidia-device-plugin.yaml`: NVIDIA device plugin daemonset for GPU runtime
  discovery

## Why It Matters

The serving workload requests `nvidia.com/gpu: 1`. That request is not usable
until the NVIDIA device plugin is running on the GPU nodes that Karpenter
launches.

The daemonset is intentionally scoped to the GPU fleet:

- node selector `workload=gpu`
- toleration for `gpu=true:NoSchedule`

That keeps the runtime prerequisite aligned with the same isolation model as the
serving workload.

## Related Components

- the AWS Load Balancer Controller is installed with Helm by `./scripts/up`
- its service account manifest lives under
  `platform/controller/aws-load-balancer-controller/`
