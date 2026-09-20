---
id: B-20
title: "Re-measure the ceiling on a paged-allocator build"
status: open
priority: P0
size: S
stage: stage-1-ceiling
blocked_by: [B-18]
---

# B-20 — Re-measure the ceiling on a paged-allocator build

RQ1 is a share, and it was measured on a binary that sets `pagedAllocator=false` against a
Kotlin/Native default of `true`. The libc bucket that choice produces is **26–46 % of samples**,
and it sits in RQ1's denominator. **So "the mechanism has nowhere to pay off here" is conditional
on a build property rather than on the platform**, and the study's headline rests on it.

- **The decision and its reason.** Re-run [B-17](B-17-rq1-second-point.md)'s protocol unchanged —
  same endpoints, same rule for the rate, same grammar — on a build whose only difference is
  `-Pxyk.allocator=default`. One variable, everything else held.
- **The reason the pin is what it is, and why this does not overturn it.** The subject's own
  repository measured the trade: paged survives a 64 MiB limit 1 time in 10, paged-off 10 times
  in 10, and the swap costs 13 % of ingest throughput. **The setting buys the product's memory
  criterion.** This item asks what the *ceiling* looks like without it, not whether xyk should
  ship it.
- The rejected alternative is inferring the answer from the libc share. The buckets do not simply
  move from libc to Kotlin — a different allocator changes how much total work there is.
- Not covered: whether to change xyk. That is a product decision with a memory criterion attached.

- AC: the five-bucket table per endpoint on the paged build, at rates re-derived by A2.2's rule —
  **the knees will move, so they are re-measured rather than reused**.
- AC: **Kotlin self plus runtime** reported per endpoint, since that is what A2.3's drop rule
  reads and what decides whether the macro probe is worth running at all.
- AC (control): the arithmetic control from B-07 is re-profiled through the same pipeline and
  still reports above 80 % Kotlin, because the allocator build is a new binary and the grammar
  has not been exercised on it.
- AC: peak RSS is recorded beside the shares. If the paged build cannot hold the service's own
  memory criterion, that belongs next to any ceiling it produces.
- Anchors: `logs/b-20/`, `pgo-native-spike/bench/ceiling2.sh`, `xyk/server/build.gradle.kts`.
