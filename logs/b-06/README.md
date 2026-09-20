# B-06 — the attribution grammar

| File | Read it for |
|---|---|
| `2026-09-20-symbol-census.log` | the eight `k*:` prefixes with symbol counts, and the line that decides H4: of 11 804 `FUNC` symbols, every Kotlin-prefixed one is `kfun:` |
| `2026-09-20-symbol-classes.log` | ELF type per prefix, and the Rust mangling census — legacy `_ZN…17h` is **0**, v0 `_R…` is 1 274, so A1.4's collision is absent from this binary |
| `2026-09-20-profile.log` | the 60 s profile at 200 rps with the generator on `bench-b` |
| `2026-09-20-bucket-census.log` | **the grep version, and it is wrong**: `k[a-z]+:` matches `kotlin::`, so "other prefixes" and "runtime" came out at 10 708 each. Two buckets that share no symbols reporting the identical count is the tell |
| `2026-09-20-buckets.log` | the grammar's output: six rows, 86 073 frames, reconciles, zero unresolved |
| `2026-09-20-leaves.txt` | the raw `perf script` leaves the table is computed from, so the table can be recomputed |
