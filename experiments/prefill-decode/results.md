# Prefill Vs Decode Timing Results

> Auditable evidence: the reports behind these tables are committed under
> `evidence/`. Replay them without a cluster with
> `./scripts/experiment replay --experiment prefill-decode`.

Status: default-profile streaming runs are populated for the prefill-heavy,
decode-heavy, and mixed cases. Scheduler variant runs exist for the mixed case;
the current conclusion is limited to the checked-in default model and vLLM
`v0.9.0` path.

## Default Profile Run Matrix

| Case | Prompt/output | Completed | Failed | p50 TTFT | p95 TTFT | p50 inter-token latency | p95 inter-token latency | p95 latency | Generation tokens/sec | Peak waiting / running / active | GPU avg / max | Outcome |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| `prefill-heavy` | 1536 / 64 | 800 | 0 | 0.775977s | 1.371081s | 0.012540s | 0.014293s | 2.244804s | 48.80 | 13 / 16 / 16 | 88.50% / 95% | higher TTFT, short total latency |
| `decode-heavy` | 128 / 768 | 160 | 0 | 0.135794s | 0.149065s | 0.010238s | 0.011477s | 8.407781s | 97.08 | 0 / 16 / 16 | 42.00% / 84% | low TTFT, long decode path |
| `mixed-prefill-decode` | 1536/64 + 128/768 | 640 | 0 | 0.137808s | 0.453633s | 0.012740s | 0.014341s | 12.524268s | 67.95 | 1 / 24 / 24 | 87.67% / 93% | decode dominates total latency |

## Mixed Shape Split

The mixed run used a 50/50 request-shape split on the `default` profile.

| Shape | Prompt/output | Completed | Failed | p95 latency | p95 TTFT | p95 inter-token latency | Generation tokens/sec |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `prefill-heavy` | 1536 / 64 | 303 | 0 | 1.516881s | 0.495291s | 0.014502s | 69.03 |
| `decode-heavy` | 128 / 768 | 337 | 0 | 12.793314s | 0.442881s | 0.014324s | 66.97 |

## Mixed Scheduler Variants

| Profile | Completed | Failed | p95 latency | p95 TTFT | p95 inter-token latency | Generation tokens/sec | Peak waiting / active | GPU avg / max | Outcome |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| `default` | 640 | 0 | 12.524268s | 0.453633s | 0.014341s | 67.95 | 1 / 24 | 87.67% / 93% | best balanced mixed profile |
| `max-seqs-16` | 640 | 0 | 17.559118s | 8.270965s | 0.011982s | 83.73 | 17 / 32 | 90.33% / 97% | queueing moved into TTFT |
| `max-seqs-8` | 640 | 0 | 29.880727s | 15.992993s | 0.009313s | 108.86 | 24 / 32 | 58.19% / 90% | lower inter-token latency but much worse TTFT |
| `batched-tokens-4096` | 640 | 0 | 20.893588s | 1.059188s | 0.016948s | 54.75 | 0 / 32 | 43.30% / 91% | batched-token cap hurt mixed throughput |

## Reports

- `prefill-heavy`: `docs/reports/experiment-prefill-decode-prefill-heavy-default-20260506-110543.json`
- `decode-heavy`: `docs/reports/experiment-prefill-decode-decode-heavy-default-20260506-111546.json`
- `mixed-prefill-decode` default: `docs/reports/experiment-prefill-decode-mixed-prefill-decode-default-20260506-173400.json`
- `mixed-prefill-decode` `max-seqs-16`: `docs/reports/experiment-prefill-decode-mixed-prefill-decode-max-seqs-16-20260506-145639.json`
- `mixed-prefill-decode` `max-seqs-8`: `docs/reports/experiment-prefill-decode-mixed-prefill-decode-max-seqs-8-20260506-152149.json`
- `mixed-prefill-decode` `batched-tokens-4096`: `docs/reports/experiment-prefill-decode-mixed-prefill-decode-batched-tokens-4096-20260506-154103.json`

## Interpretation

The standalone prefill-heavy case shows the expected prompt-processing cost:
p95 TTFT rose to 1.37s, but total p95 latency stayed near 2.24s because output
length was short. The standalone decode-heavy case had much lower TTFT at
0.15s, but p95 request latency rose to 8.41s because generation dominated the
request.

In the mixed case, decode-heavy requests dominate total tail latency while
prefill-heavy requests contribute TTFT pressure. Capping `max_num_seqs` did not
protect the mixed workload's tail latency; it shifted delay into queueing and
TTFT. Limiting the batched-token budget also regressed mixed throughput.

Decision impact: treat prefill and decode SLOs separately. A profile that looks
healthy on total latency for short outputs can still have high TTFT under long
prompts, while decode-heavy traffic needs a separate inter-token and total
latency budget.

## Graphs

- [Streaming timing split](graphs/streaming-timing.svg) compares p95 TTFT with
  p95 total request latency for the default prefill-heavy, decode-heavy, and
  mixed runs.

## Boundaries

- The conclusion is scoped to the checked-in default model and vLLM `v0.9.0`
  path.
- Scheduler variants were tested only for the mixed case, not for each
  standalone prefill-heavy or decode-heavy workload.
- Treat the default scheduler as the mixed-profile baseline until a new profile
  improves TTFT and total latency together.
