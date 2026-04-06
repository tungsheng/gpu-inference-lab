# Reports

This directory is intended for generated validation artifacts, such as the
Markdown timeline report written by:

```bash
./scripts/dev measure --report docs/reports/dynamic-gpu-serving-$(date +%Y%m%d-%H%M).md
```

Generated reports are not required for the repo to function, but they are the
easiest way to capture cold-start, first-external-completion, scale-out, and
scale-down timing for the current external-edge GPU serving milestone.
