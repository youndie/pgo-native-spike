---
id: B-20
title: "Re-measure the ceiling on a paged-allocator build"
status: done
priority: P0
size: S
stage: stage-1-ceiling
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

---

## Unblocked — 2026-09-20

**This item was blocked on [B-18](B-18-allocator-probe.md) and should not have been.** B-18 has
two halves: the allocator *build* comparison, which is done and gave the 19 % figure this item
exists to follow up, and an `LD_PRELOAD` probe of a faster system malloc, which is a different
question and stays open as P2.

The dependency was written when both were one item. It left **the most valuable measurement in
the backlog waiting on a side-probe two priority levels below it** — the kind of inversion that
is invisible until someone asks what the loop would pick next.

---

## Findings — 2026-09-20

# A2.3's drop rule **fires**. Route A, RQ5 and RQ6 are dropped

On the paged-allocator build, at rates re-derived from knees this build actually reaches,
**Kotlin self plus runtime is 28.4–28.6 % on every work endpoint** — well under the 40 % the rule
names, and remarkably consistent across three endpoints that do very different work.

| endpoint | rate | knee | Kotlin self | runtime | **self + runtime** | paged-off was |
|---|---:|---:|---:|---:|---:|---:|
| `GET /health/live` | 2400 | 4000 | 42.29 % | 5.15 % | 47.43 % | 50.38 % |
| `POST /hooks/{id}` | 240 | 400 | 25.87 % | 2.58 % | **28.46 %** | 32.33 % |
| `GET /api/events` | 180 | 300 | 23.87 % | 4.49 % | **28.37 %** | 37.12 % |
| `GET /journal` | 144 | ≥240 | 21.95 % | 6.62 % | **28.57 %** | 41.24 % |

Zero unresolved samples; every run delivered its offered rate; three of four knees found.

### The allocator does not open room for PGO — it closes it

This was the experiment's whole point and the answer is counter-intuitive. The paged allocator
makes the service **19 % cheaper per request** ([B-18](B-18-allocator-probe.md)) and **raises
Kotlin's share** on every endpoint — `/journal` goes 13.84 % → 21.95 %, `/api/events` 16.40 % →
23.87 %. But the **runtime bucket collapses further than Kotlin's grows**: 27.40 % → 6.62 % on
`/journal`, 20.72 % → 4.49 % on `/api/events`.

**Their sum — the most arm A3 can touch — falls on every work endpoint**, from 32–41 % to a
uniform ~28.5 %. The cheaper allocator removes work that was PGO's territory rather than moving
work into it.

**So the conclusion does not depend on the build property after all**, which is what the review
asked to establish. It fires either way: on paged-off the rule missed by 1.24 points on one
endpoint, and on paged it fires by more than 11 on all three.

### RQ1's own verdict is unchanged: still grey

Green needs 40 % Kotlin self on a majority of endpoints. Only `/health/live` reaches it (42.29 %),
and one of four is not a majority. Red needs under 20 % everywhere; the lowest is 21.95 %.
**Grey on both allocators, with different numbers.**

### A bias that ran the other way

The short-ladder attempt measured at 60 % of a *lower bound* and I set it aside, expecting
A2.2's warning to apply — too low a rate inflates the kernel bucket and deflates everything else,
which would have made the rule fire falsely.

**It ran the other way.** At the proper, higher rates the sum came *down* — 30.18 → 28.46,
36.15 → 28.37, 34.49 → 28.57 — because libc grew with load (`/api/events` 38.43 % → 49.37 %)
faster than the kernel shrank. The rule fires **more** clearly at the correct rate, not less, so
the verdict does not rest on the rate being exactly right.

### Not covered

`/journal`'s knee is still not found — it delivered 240 rps cleanly and the ladder stopped there —
so its rate is 60 % of a lower bound. Its number is in line with the other two and the direction
of the remaining bias is now measured to be small, but it is the one row that is not on a knee.

Peak RSS was not recorded. The AC asked for it because a paged build may not hold the service's
own memory criterion, and that qualification belongs beside any ceiling it produces — it is
[B-18](B-18-allocator-probe.md)'s 1-in-10 survival figure, measured by the subject rather than
here.
