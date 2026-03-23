# platform/karpenter

This directory contains the Kubernetes manifests used for the optional
Karpenter dynamic-compute milestone:

- `serviceaccount.yaml`
- `nodeclass-default.yaml`
- `nodepool-default.yaml`

These manifests assume the current dev cluster name `gpu-inference` and the
Terraform-created Karpenter node role `gpu-inference-karpenter-node`.

The default `EC2NodeClass` is pinned to the EKS AL2023 alias `al2023@v20260304`
for Kubernetes `1.35`.

This path is separate from the default managed GPU baseline documented in
`docs/scaling.md`.
