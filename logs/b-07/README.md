# B-07 — RQ1, the ceiling

| File | Read it for |
|---|---|
| `2026-09-20-control-build.log`, `-control-leaves.txt`, `-control-buckets.log` | the positive control: integer arithmetic, no allocation, compiled with `kotlinc-native -opt`. **99.96 % `kfun:`** — the pipeline can report a high Kotlin share, so a low one is about the subject |
| `raw/{ingest,apievents,health}-stacks.txt.gz` | the three endpoints profiled at the pinned 200 rps |
| `raw/journal-stacks.txt.gz` | **`/journal` at 200 rps, and it is saturated** — 142 delivered of 200 offered, p50 1.3 s. Reports 55.55 % Kotlin, against 14.92 % for the same endpoint when it is not saturated. Kept because the difference is the finding |
| `raw/journal40-stacks.txt.gz` | `/journal` at 40 rps, clean, p99 13.7 ms — the row that counts |
| `raw/*-k6.txt` | the generator's side per endpoint |
| `2026-09-20-per-endpoint.log` | the tables **as first computed**, before the parser and return-type bugs were fixed: libc overstated and runtime understated by 4–12 points. `kfun:` is identical, which is why the verdict did not move |
| `2026-09-20-top-symbols.log` | what the non-Kotlin majority is: `PerformFullGC`, `_int_malloc`, `__libc_calloc`, `malloc_consolidate`, `CustomAllocator::CreateObject`. This listing is what exposed the parser bug — `void` cannot be a symbol name |

The `*-stacks.txt.gz` files are `perf script -F ip,sym,dso` output with call graphs, stored
compressed because one endpoint's raw output is 284 MB and 3 MB gzipped. `scripts/attribution.py`
and `scripts/ceiling_report.py` read either form, so every table here recomputes from what is
committed.
