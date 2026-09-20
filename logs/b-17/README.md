# B-17 — RQ1's second point

| File | Read it for |
|---|---|
| `rates.csv` | each endpoint's knee and the 60 % rate measured at |
| `raw/sweep-*.log` | the saturation sweeps. `/journal` reached 80 rps without saturating, so its knee is a **lower bound** and its rate is 60 % of that, not of the knee |
| `raw/*-fp-stacks.txt.gz` | the frame-pointer captures — the self buckets and, for want of anything better, the inclusive column |
| `raw/*-dwarf-stacks.txt.gz` | **kept as the negative result.** Kernel-only stacks, zero Kotlin frames. On the arithmetic control dwarf returns zero stacks entirely |
| `2026-09-20-buckets.log` | the table the drop rule is read off |
| `2026-09-20-malloc-callers.log` | who calls libc malloc: `CustomAllocator::CreateObject` and `CreateArray` above everything else |

The drop rule does not fire: `/journal` is at 41.24 % Kotlin self plus runtime against a 40 %
threshold, and at 24 710 samples the binomial interval is ±0.61 %, so it is above 40 with
confidence rather than by rounding.
