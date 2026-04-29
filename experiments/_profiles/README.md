# Shared Experiment Profiles

This directory holds defaults shared by the experiment catalog.

- `serving-defaults.csv`: baseline vLLM model, image, resource, cache, and
  runtime settings used when an experiment profile leaves a field blank

Experiment-specific `serving-profiles.csv` files should only override fields
that matter to that experiment, such as context length, scheduler limits, or
resource changes.
