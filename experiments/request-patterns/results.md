# Request Pattern Utilization Results

> Auditable evidence: the reports behind these tables are committed under
> `evidence/`. Replay them without a cluster with
> `./scripts/experiment replay --experiment request-patterns`.

Curated live-cluster run: 2026-05-15 UTC, one `default` vLLM replica on the
current g4dn path.

## Result Matrix

| Case | Target rate | Successful | Dropped | Delivery ratio | p95 latency | Requests/sec | Tokens/sec | Peak waiting | Peak active | Avg GPU | Max GPU |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `steady-small` | 6 | 1889 | 0 | 1.000000 | 1.29s | 5.90 | 755.60 | 0 | 7 | 69.0% | 84% |
| `burst-small` | 18 | 2283 | 327 | 0.874713 | 8.56s | 13.36 | 1709.53 | 1 | 127 | 77.3% | 79% |
| `uneven-size-mix` | 8 | 2661 | 8 | 0.997003 | 7.87s | 7.39 | 949.51 | 1 | 25 | 65.2% | 84% |
| `spike-to-zero` | 20 | 1635 | 415 | 0.797561 | 8.45s | 14.10 | 1805.15 | 0 | 128 | 75.5% | 76% |

## Source Reports

- `docs/reports/experiment-request-patterns-steady-small-default-20260514-164928.json`
- `docs/reports/experiment-request-patterns-burst-small-default-20260514-170305.json`
- `docs/reports/experiment-request-patterns-uneven-size-mix-default-20260514-170637.json`
- `docs/reports/experiment-request-patterns-spike-to-zero-default-20260514-171308.json`

## Interpretation

Steady homogeneous `512/128` traffic stayed comfortably inside the one-GPU
default profile: no drops, no waiting pressure, and p95 latency near 1.3s.

Burst and spike traffic pushed active concurrency to the profile edge
(`127-128` active requests) while keeping the measured waiting queue near zero.
That means direct clients overflowed at the client side instead of building a
long server-side queue: delivery dropped to 87.5% for `burst-small` and 79.8%
for `spike-to-zero`.

The uneven-size mix preserved delivery ratio but widened the latency tail. Its
p50 was 1.09s while p95 reached 7.87s, which points to request-shape effects
even without a populated per-shape latency split in the generated report.

GPU utilization stayed materially workload-shaped. Steady traffic averaged 69%,
bursts averaged about 77%, and the mixed-size run averaged 65% while using much
more GPU memory. The pattern matters enough that scheduler and admission
recommendations should not be based on one steady workload alone.

## Graphs

- [Request pattern matrix](graphs/request-pattern-matrix.svg) compares delivery
  ratio and p95 latency across the four default-profile traffic shapes.

## Boundaries

- The `uneven-size-mix` report did not populate per-shape latency buckets, so
  the mixed-shape conclusion is based on aggregate p50/p95/p99, memory, and
  active-request pressure.
- These runs use direct clients with no admission buffer. Dropped iterations are
  client-side unserved work, not successful backpressure handling.
