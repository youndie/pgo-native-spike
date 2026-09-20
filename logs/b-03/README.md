# B-03 — the ruler

Raw output behind [B-03's findings](../../docs/backlog/B-03-the-ruler.md). Captured on the Mac
over ssh; nothing kept was written on either host.

| File | Read it for |
|---|---|
| `ceiling-void-first-attempt.csv` | **void, and kept as the mistake it is.** The first ceiling probe POSTed to `/health/live` with the criterion's 200-VU pool. `ingest.js` sends GET only when `ARM=control`, so every request was a non-200 on an error path; and a pool of 200 cannot offer more than `200/latency`, which is the 400 rps plateau it reported and mistook for a ceiling. Both traps are documented in `ingest.js` itself |
| `ceiling.csv` | the corrected probe: two sweeps. The `generator` rows still saturate the **subject** rather than the generator — 8 000 VUs against four cores — and are not the generator's ceiling either |
| `raw/gen-vs-twin-*.log` | the generator's capacity, asked of something that can absorb it: the Go twin. 2 000 offered → 1 997.7 delivered, 0 dropped; first strain at 8 000. The twin answers 404 on `/health/live`, so the check fails while the round trips are real — it is a capacity probe, not a correctness one |
| `ruler.csv`, `raw/ruler-*` | the ruler itself: the same binary as both arms, five rounds, round 1 discarded |
| `control.csv`, `raw/control-*` | the positive control: arm b under a concurrent load, which must land outside the ruler |

**The subject's knee is between 300 and 400 rps** on `/hooks/{id}`: 100, 200 and 300 offered come
back exact with zero dropped and p50 5.3–6.7 ms; 400 offered delivers 345.9 with 671 dropped and
p50 564 ms. The ruler is taken at **200 rps**, half the knee. A ruler taken on a saturated subject
measures the saturation.

## The runs, in the order they happened

| CSV | gap between rounds | paired ruler | why it exists |
|---|---|---:|---|
| `ruler-provisional-broken-gate.csv` | 50–110 s, variable | ±5.6 % | idle gate v1: one-minute load average, a threshold this run cannot reach; waited 150 s and proceeded |
| `ruler-provisional-gate-v2.csv` | ~140 s, fixed | ±3.9 % | idle gate v2: `/proc/stat` by fixed field positions, eight assumed, ten printed; reported "busy 9 cores" on a four-core box |
| `ruler-settle20.csv` | ~24 s, fixed | ±5.5 % | the first run with a working gate |
| `ruler.csv` | 120 s, fixed | ±4.6 % | the settle experiment; drifts +441 µs/round, R² 0.94 |
| `control.csv` | — | — | arm b under a two-core hog: 17 113 µs against 7 832, 2.19× |

All four are kept. Pooling their sixteen paired differences is where the ruler's 2.92 % standard
deviation comes from, and the spread of their *unpaired* numbers — 3.2 % to 13.0 % — is the
evidence that the unpaired estimator is the wrong one.
