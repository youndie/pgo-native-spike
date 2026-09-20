# B-09 — RQ2, indirect call promotion

| File | Read it for |
|---|---|
| `2026-09-20-promoted-site.ll` | the guarded, inlined call site in `itable` — the evidence for RQ2's first green condition |
| `2026-09-20-repeats-interleaved.txt` | the measurements that count: nine interleaved rounds, three modes, two arms |
| `2026-09-20-intervals-interleaved.log` | those reduced to 99 % intervals by `scripts/bench_stats.py` |
| `2026-09-20-repeats.txt`, `-intervals.log` | **void, and kept as the mistake.** Not interleaved — all of A0 then all of A2 — and the unit control separated by 31.5 % on the uniform arm, which a profile cannot cause |

The benchmark is `probes/dispatch-bench.kt`; the recipe is
[B-08's](../b-08/README.md), with `pgo-icall-prom` and `default<O3>` added to the `opt` pass list
and both kotlinc pipelines set to `verify`.
