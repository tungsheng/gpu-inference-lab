# FP4 Quantization Optimization

## Goal

Compare the BF16 Qwen2.5 7B baseline with two Blackwell FP4 artifacts:

| Profile | Quantization | Optimization |
| --- | --- | --- |
| `bf16-baseline` | BF16 | none |
| `nvfp4-plain` | NVFP4 W4A4 | none |
| `nvfp4-smoothquant` | NVFP4 W4A4 | SmoothQuant strength 0.5 before quantization |

The experiment asks whether SmoothQuant improves NVFP4 accuracy recovery and
what that costs in memory, latency, throughput, and dollars.

## Fixed Comparison Contract

All three serving profiles target `p6-b200.48xlarge` in `us-west-2`, use
`vllm/vllm-openai:v0.20.1`, render `--dtype auto`, and set
`--tensor-parallel-size 8` so serving cost is attributed to the full 8 GPU
instance. The rendered pods select `p6-b200.48xlarge` directly, while the
NodePool labels resulting nodes with `gpu-arch=blackwell` for observability.
The shared g4dn/g5 profiles are unchanged.

Both quantized artifacts use the same calibration contract:

| Field | Value |
| --- | --- |
| Dataset | `HuggingFaceH4/ultrachat_200k` |
| Split/config | `train_sft` |
| Samples | `512` |
| Max sequence length | `2048` |
| Seed | `42` |

## Accuracy

The accuracy case is 0-shot with `limit=200` for:

- `arc_easy`
- `hellaswag`
- `winogrande`

Reports include raw task scores, average score, FP4 recovery versus BF16, and
SmoothQuant gain versus plain NVFP4.

## Cost

Serving cost defaults live in `cost-profiles.csv` and `cost-details.csv` so the
pricing can be updated without code changes. The default source is AWS EC2
Capacity Blocks for ML in US West Oregon:

- p6-b200.48xlarge instance: `$82.368/hr`
- B200 accelerator: `$10.296/hr`
- accelerator count: `8`
- Linux OS: `$0/hr`

Reports keep one-time quantization build cost separate from recurring serving
cost.

## Commands

Local render-only checks:

```bash
./scripts/experiment validate

./scripts/experiment render-quantization \
  --experiment fp4 \
  --profile nvfp4-plain \
  --output /tmp/fp4-nvfp4-plain-quantize.yaml

./scripts/experiment render-quantization \
  --experiment fp4 \
  --profile nvfp4-smoothquant \
  --output /tmp/fp4-nvfp4-smoothquant-quantize.yaml

./scripts/experiment render-serving \
  --experiment fp4 \
  --profile bf16-baseline \
  --output /tmp/fp4-bf16-serving.yaml

./scripts/experiment render-accuracy \
  --experiment fp4 \
  --profile nvfp4-smoothquant \
  --output /tmp/fp4-accuracy.yaml

./scripts/experiment render-report \
  --experiment fp4 \
  --case steady-512-output-128 \
  --profile nvfp4-smoothquant
```

Live run order after the Blackwell capacity path and model artifact storage are
ready:

1. Apply `platform/inference/model-artifacts-pvc.yaml` if the `model-artifacts`
   PVC does not already exist.
2. Render and apply `nvfp4-plain` and `nvfp4-smoothquant` quantization jobs.
3. Run one smoke completion for each serving profile.
4. Run latency workloads for each serving profile.
5. Run accuracy workloads for each serving profile.
6. Produce a comparison table covering memory reduction, p95/p99 latency,
   tokens/sec, accuracy recovery, serving cost, and quantization build cost.

## Sources

- AWS Capacity Blocks pricing: https://aws.amazon.com/ec2/capacityblocks/pricing/
- LLM Compressor NVFP4 example: https://docs.vllm.ai/projects/llm-compressor/en/latest/examples/quantization_w4a4_fp4/
- LLM Compressor SmoothQuant reference: https://docs.vllm.ai/projects/llm-compressor/en/latest/reference/llmcompressor/modifiers/smoothquant/
- vLLM quantization docs: https://docs.vllm.ai/en/latest/features/quantization/
