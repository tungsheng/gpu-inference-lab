# Evidence

Curated cross-experiment readout: what the repository supports, what remains a
hypothesis, and where the source details live.

Generated artifacts under `docs/reports/` are raw inputs. Stable numbers and
tables belong in `experiments/<name>/results.md`; this page keeps the
architecture conclusions compact. For the action-oriented operator readout, see
[Recommendations](recommendations.md).

## Supported Conclusions

### Autoscaling And Admission

Source: `experiments/autoscaling/results.md`

Supported claim: bounded admission belongs in front of serving when traffic can
arrive before GPU capacity and model readiness catch up.

Key signal: Karpenter produced serving NodeClaims in `3-12s` and GPU nodes in
about `35s`, while vLLM model readiness took `425-439s`. Direct burst/spike
clients completed more work in the fixed window, but dropped `237-787` client
iterations and saw p95 latency around `14s`; bounded queued clients kept
delivery at `1.000000` and p95 latency near `2s`.

Boundary: burst cases predate full cold-start timeline capture, so use the
spike cases for provisioning-stage timing.

### Active-Pressure HPA Tuning

Source:
`docs/reports/evaluate-warm-1-compare-20260514-174643-compare.md` and
`docs/reports/evaluate-zero-idle-active-pressure-sweep-20260514-191700-active-pressure-sweep.md`

Supported claim: active-pressure HPA is measurable end to end, but the current
target recommendation is not a production optimum.

Key signal: in the warm-one compare, both running-request and active-pressure
policies were underutilized with p95 estimated queue wait at `0s`.
Active-pressure made the second replica ready faster (`571s` versus `966s`),
but did not improve run-level throughput or cost. In the zero-idle sweep,
targets `2`, `4`, `6`, and `8` were all underutilized; target `8` is only the
highest underutilized target tested.

Boundary: repeat under higher offered pressure or a different capacity shape
before promoting an HPA target.

### KV Cache And Long Context

Source: `experiments/kv-cache/results.md`

Supported claim: the current single-replica, one-GPU `long-context` profile has
a repeatable `8192/300` saturation knee and needs an admission or concurrency
boundary.

Key signal: `1.10 req/s` repeats stayed stable with no waiting and p95 latency
near `25s`; `1.15 req/s` repeatedly introduced queue delay around `14s`; and
`1.20 req/s` became queue-dominated with p95 request latency around `63s`.
At `1.25 req/s`, active admission capped at `32` cut p95 latency from `77.51s`
to `27.98s`, reduced p95 queue delay from `48.11s` to `0.285s`, and reported
`59` dropped client iterations as explicit unmet demand.

Boundary: the clearest capacity knee is the `8192/300` workload. Smaller prompt
lengths need their own matrix before generalizing the stable rate.

### FP8 KV Cache On Current g4dn Path

Source: `experiments/kv-cache/results.md`

Supported claim: do not select FP8 KV cache for the current one-GPU
g4dn/vLLM `v0.9.0` long-context path.

Key signal: the baseline `long-context` profile delivered all `599` requests at
p95 `11.92s` and `249.58` generated tokens/sec. FP8 KV variants reduced
delivery ratio to `0.475793-0.691152`, pushed p95 latency to `245-300s`, and
cut generated-token throughput to `114-166` tokens/sec while saving only about
`0.07 GiB` in this workload.

Boundary: retest only with a newer vLLM image, different GPU backend, or a
smaller prompt case where memory pressure is the primary hypothesis.

### Small-Request Scheduler Defaults

Source: `experiments/batching/results.md`

Supported claim: keep vLLM dynamic scheduler defaults as the small homogeneous
`512/128` baseline.

Key signal: the default profile delivered the best steady and burst results.
Under steady load it reached full delivery with p95 `1.66s`; under burst load it
kept delivery at `0.975670`, p95 `6.79s`, and generated-token throughput above
`1800` tokens/sec. Explicit sequence and batched-token caps shed more work and
had worse tails.

Boundary: this does not prove scheduler behavior for mixed-size fairness
objectives.

### Request Pattern Utilization

Source: `experiments/request-patterns/results.md`

Supported claim: traffic shape materially changes useful throughput, latency,
memory pressure, and delivery ratio on the same serving profile.

Key signal: steady traffic had full delivery and p95 `1.29s`; burst and
spike-to-zero traffic pushed active concurrency to `127-128` and dropped
`327-415` client iterations; the uneven-size mix preserved delivery ratio
(`0.997003`) but widened p95 latency to `7.87s`.

Boundary: the uneven-size report did not populate per-shape latency buckets, so
the mixed-shape conclusion remains aggregate.

### Cost Per Useful Work

Source: `experiments/cost/results.md`

Supported claim: batching is strongly supported for small-request economics,
but burst SLO compliance still needs admission, autoscaling, or more capacity.

Key signal: for steady traffic, `optimized-batched` delivered `2670` successful
requests, passed the p95/p99 SLO, and cost `$0.019752` per 1K successful
requests. `naive-single` delivered `413`, missed the SLO, and cost `$0.137976`
per 1K successful requests. For burst traffic, optimized batching was still far
cheaper per useful request, but p95 latency was `10.91s` and the SLO failed.

Boundary: cost scope is serving-GPU-only; it excludes control plane, network,
storage, observability, idle platform cost, and operator time.

### Prefill And Decode Timing

Source: `experiments/prefill-decode/results.md`

Supported claim: streamed workloads need separate TTFT, inter-token, and total
latency budgets.

Key signal: prefill-heavy traffic raised p95 TTFT to `1.371s` while keeping p95
total latency at `2.245s`; decode-heavy traffic kept p95 TTFT at `0.149s` but
raised total p95 latency to `8.408s`; the mixed case was dominated by
decode-heavy tail latency at p95 `12.524s`.

Boundary: scheduler variants were tested only for the mixed case on the current
default model and vLLM `v0.9.0` path.

## Partial Or Pending Evidence

| Area | State | Recommendation needs |
| --- | --- | --- |
| Active-pressure HPA target | fresh compare and zero-idle sweep reports are complete, but all tested targets were underutilized | repeat under higher pressure or alternate capacity shapes before selecting a production target |
| Server-side timing breadth | targeted long-context reruns now separate queue, prefill, decode, TTFT, inter-token, and e2e timing; older reports predate those histograms | repeat targeted cases when changing vLLM versions, scheduler profiles, or admission caps |
| Batching scheduler breadth | steady and burst matrices support dynamic default for homogeneous `512/128`; fairness and richer mixed-size cases remain pending | mixed request-size and fairness runs before generalizing scheduler caps |
| Prefill/decode profile tuning | default and mixed scheduler reports exist; repeat or variant sweeps remain pending | variance checks or new profiles before making broad scheduler claims |
| Blackwell FP4 | renderers and cost model exist; live p6-b200 attempt blocked by `UnfulfillableCapacity` | BF16, NVFP4, and SmoothQuant runs with accuracy, latency, throughput, memory, and cost |

## Evidence Rules

- Use ignored generated reports as raw inputs.
- Promote representative, explainable result tables into
  `experiments/<name>/results.md`.
- Keep this page about architecture decisions, not every run.
- Do not claim optimized autoscaling targets from underutilized sweeps or
  partial reports with missing DCGM or queue fields.
