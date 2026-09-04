# Shared Experiment Profiles

This directory holds defaults shared by the experiment catalog.

- `serving-defaults.csv`: baseline vLLM model, image, resource, cache, and
  runtime settings used when an experiment profile leaves a field blank

Experiment-specific `serving-profiles.csv` files should only override fields
that matter to that experiment, such as context length, scheduler limits, or
resource changes.

## Serving Images

The `vllm_image` column holds a symbolic reference, not a tag:

| Reference | Resolves to |
| --- | --- |
| `@VLLM_IMAGE_DEFAULT@` | the legacy baseline behind the curated evidence corpus |
| `@VLLM_IMAGE_MODERN@` | the current target for new work |
| `@VLLM_IMAGE_BLACKWELL@` | the Blackwell / NVFP4 path |

`platform/inference/versions.env` declares what each one means. References are
expanded when a profile is loaded, so nothing downstream sees the symbolic form,
and `./scripts/experiment validate` rejects a reference it cannot resolve.

Write a literal tag only when a profile deliberately pins an image that no other
part of the lab shares.
