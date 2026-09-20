---
id: B-18
title: "The allocator probe: LD_PRELOAD jemalloc or mimalloc, outside the verdicts"
status: wip
priority: P2
size: S
stage: stage-1-ceiling
blocked_by: [B-17]
---

# B-18 — The allocator probe, logged outside the verdicts

RQ1 found that the largest single bucket on three of four endpoints is libc, and that its content
is `_int_malloc`, `__libc_calloc` and `malloc_consolidate` — **glibc** functions, in a binary that
carries Kotlin/Native's own allocator. Something is calling libc malloc heavily.

`PerformFullGC` alone is 4.4–11.3 % on top of that. Together the allocator and the collector are
a larger share of this service's CPU than the Kotlin code PGO can touch.

- **The decision and its reason.** An `LD_PRELOAD` of jemalloc or mimalloc is **one hour and no
  compiler work**, and its plausible effect is larger than the best case for PGO. Not doing it
  because it is not in the brief would be letting the document choose the finding.
- **It is logged outside the verdicts.** Allocator changes are an explicit non-goal
  ([BRIEF.md](../../BRIEF.md)), so this produces no RQ verdict and does not enter the verdict
  table. It goes in the write-up as a pointer, and it is the natural RQ1 of a different study.
- The rejected alternative is changing the Kotlin/Native allocator option, which is a rebuild, a
  different binary and a real arm — this is a preload and changes nothing about the subject.
- Not covered: deciding anything. A number here is a reason to write a brief, not a reason to
  ship a flag.

- AC: the same endpoints at the same rates as [B-17](B-17-rq1-second-point.md), with and without
  the preload, through [B-03](B-03-the-ruler.md)'s protocol at eight counted rounds so the result
  can be read against the ruler.
- AC: the preload is shown to have taken effect — the malloc symbols in a profile come from the
  preloaded library and not from glibc. **A preload that silently did not load produces exactly
  the null this probe might otherwise report.**
- AC: the result is reported as µs of CPU per request against A0, with the ruler beside it, and
  **no RQ verdict attached**.
- Anchors: `logs/b-18/`, `pgo-native-spike/bench/ruler.sh`.

---

## Iteration 1 — 2026-09-20. The default allocator is 19 % cheaper per request

**One build flag, already the platform default, is worth 19.01 % of CPU per request — about four
times the macro threshold this entire study was built to detect, and it needs no compiler work.**

| arm | µs CPU per request |
|---|---:|
| `pagedAllocator=false` — **what the pin uses** | **8 175** |
| `pagedAllocator=true` — the Kotlin/Native **default** | **6 756** |
| paired difference | **+19.01 %**, 95 % CI **±2.33 %** |

Eight counted rounds at 180 rps, arms interleaved, 120 s settle, zero dropped, accounting closes
on every round. Per-round sd **2.79 %** against the pooled ruler's 2.92 %, so the run is as
well-behaved as the stand gets.

### What it is next to

| | |
|---|---:|
| **this flag** | **−19.0 %** of request CPU |
| the brief's macro threshold | 5 % |
| the best PGO effect measured anywhere in this study | 11–13 %, on a microbenchmark dispatch loop |
| what that PGO effect is worth at service scale | ~460 000 promoted calls per request for 1 % |

### What it does **not** say

**It does not say xyk should ship it.** The pin exists for a reason the subject measured: paged
survives a 64 MiB limit **1 time in 10**, paged-off **10 times in 10** at 54.9–65.7 MB, because
Kotlin/Native holds a page per size class per thread for the life of the thread. **This run had
no container limit at all**, so it measures CPU in a configuration the product cannot currently
deploy.

The honest form is: *the setting the product needs for memory costs it a fifth of its request
CPU*, and that trade was previously priced at 13 % of ingest throughput by the subject's own
measurement. This is the same trade measured on the other axis, and larger.

**It does not re-measure the ceiling.** A cheaper allocator changes both the numerator and the
denominator of RQ1 — that is [B-20](B-20-ceiling-on-the-paged-allocator.md), and it is now the
most valuable item in this backlog.

### Still open on this item

The `LD_PRELOAD` probe of jemalloc or mimalloc, which asks a different question: whether a faster
**system** malloc helps. It matters most in the paged-**off** configuration, where
`CustomAllocator` forwards to libc — and less in the paged-on one, where it forwards less. The
two probes interact and the second should be run against whichever allocator B-20 leaves standing.
