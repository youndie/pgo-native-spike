# B-18, iteration 2 — the `LD_PRELOAD` probe. Below resolution

The question the build-flag half did not ask: does a faster **system** malloc help, given that
`CustomAllocator` forwards to libc and libc was the largest bucket on three of four endpoints?

**Answer: not measurably, and not remotely like the build flag.** `+0.65 %`, 95 % CI **±6.08 %**,
eight paired rounds at 180 rps. Against the 19.01 % ±2.33 % that `pagedAllocator` was worth, this
is a different order of thing.

## The preload cannot reach the arm this study pinned, and that is the first result

**The pinned build is `-static`, so `LD_PRELOAD` is ignored entirely.** The service starts,
answers `/health/live` with `200`, and **jemalloc appears zero times in `/proc/<pid>/maps`**.

This is precisely the failure the item's AC named in advance — *"a preload that silently did not
load produces exactly the null this probe might otherwise report"* — and here it is total rather
than subtle. Anyone running this probe against the shipped binary would measure nothing and
conclude jemalloc does not help.

So the probe runs on a **dynamically linked** build of the same commit. That is sound because
[B-21](../../docs/backlog/B-21-rq0-the-two-numbers.md) established the two builds' **IR is
byte-identical** — `staticLink` does not reach the code, only the link.

## The preload demonstrably took effect

Not asserted from the command line — read out of the process and out of a profile:

| | no preload | jemalloc preloaded |
|---|---:|---:|
| jemalloc regions in `/proc/<pid>/maps` | 0 | 5 |
| samples in `libjemalloc.so.2` | — | 68 |

And the malloc path itself moved, by symbol:

    calloc            26 samples   libjemalloc.so.2
    free               8           libjemalloc.so.2
    posix_memalign     2           libjemalloc.so.2
    malloc             2           libjemalloc.so.2
    malloc-family symbols still served by libc:  NONE

## The measurement

Eight counted rounds, arms interleaved, round 1 discarded, 120 s settle, **0 dropped, 0 % failed,
accounting closes on every round, contamination clean, `nproc` 4 as the subject sees it**.

| | µs CPU per request |
|---|---:|
| no preload | 7 750 |
| jemalloc | 7 671 |
| **paired** | **+0.65 %, 95 % CI ±6.08 %** |

**→ below resolution: the effect is under 6.08 %, which is not the same as zero.**

## The run was noisier than the ruler, and the number says so

**Per-round sd 7.27 % against the ruler's 2.92 %** — two and a half times. Eight pairs should buy
±2.44 %; they bought ±6.08 %. Two candidate causes, and this run does not separate them:

- **The stand drifted upward through the run.** Both arms sit near 7 400 µs in the early rounds
  and near 8 000 in the late ones. A stand that accumulates — the database grows as the run
  proceeds — drifts monotonically, and interleaving cancels the level but not the within-pair
  slope.
- **The ruler was never characterised on a dynamic binary.** Its 2.92 % comes from the static
  `xyk-pagedoff`. PLT indirection is a real difference and nothing here has measured its noise.

**What this licenses:** ruling out an effect anywhere near the build flag's 19 %. **What it does
not:** distinguishing a 5 % win from nothing. A tighter answer needs the stand understood rather
than more rounds — doubling the pairs only reaches about ±4.3 %.

## Outside the verdicts

Allocator work is an explicit non-goal of the brief. **No RQ verdict is attached and none of this
enters the verdict table.** It is a pointer for a different study, and the pointer now reads:
*the system allocator is not where this service's allocation cost is — the build flag is.*

Raw: `2026-09-21-jemalloc-preload.log`.
