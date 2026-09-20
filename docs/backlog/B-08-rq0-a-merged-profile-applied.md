---
id: B-08
title: "RQ0 — a profile that merges and applies, by Route B then Route A"
status: open
priority: P0
size: XL
stage: stage-2-feasibility
blocked_by: [B-05]
---

# B-08 — RQ0: a profile that merges and applies, by Route B

> **Re-scoped 2026-09-20 by [BRIEF](../../BRIEF.md) A2.4, after RQ1 came back grey.** Route A —
> the five days inside the fork — is **not** attempted. This item is Route B only, on the
> **microbenchmark binary** rather than the service, and it is time-boxed to two or three days
> together with [B-09](B-09-rq2-indirect-call-promotion.md). The mechanism answer holds at any
> offered rate, which is what makes it worth having when the macro half may not be.
>
> **It may not need the fork at all.** Route B's only requirement of the compiler is that the
> linked pre-optimisation bitcode can be got out of it. If a stock `-X` flag does that, this item
> and [B-05](B-05-six-unknowns-of-the-release-pipeline.md) come unblocked from
> [B-04](B-04-fork-at-the-pinned-tag-and-the-baseline.md) entirely — which would take the build
> host off this study's critical path. That is the first thing to check.

Feasibility, and the study's longest budget: five working days, after which kill criterion 1
applies and the write-up is the list of obstacles in the order they were hit, with the patch set as
far as it got. Green is a profile that merges and, on the macro subject, at least 80 % of functions
with non-zero counts having it applied in the rebuilt IR.

- **The decision and its reason.** Route B first — dump the linked pre-optimisation bitcode, let an
  external `opt` instrument or apply, replay the link — because it involves no compiler changes and
  shows what a correct result looks like. Route A, inside the fork, is the prototype; Route B stays
  as its oracle. A prototype with no oracle cannot tell "the pass did nothing" from "the pass did
  not run".
- The order within Route B is the brief's: hello-world, then the service. A profile that will not
  come out of a hello-world will not come out of a service, and the hello-world says so in
  minutes.
- Both passes must sit at the same point in the pipeline, because the profile is keyed by a hash of
  each function's CFG at that point. Any pass that runs before one and not the other drops
  profiles silently — and *silently* is the word that makes this an AC rather than a note.
- Not covered: performance. Nothing here is a measurement of speed; that is
  [B-09](B-09-rq2-indirect-call-promotion.md) and [B-10](B-10-rq3-rq4-the-macro-arms.md).

- AC: a `.profraw` out of the running service that `llvm-profdata merge` accepts, with
  `show --all-functions --ic-targets` printing counts per function and recorded targets per
  indirect call site.
- AC: which of the two write mechanisms works is recorded — `__llvm_profile_write_file` through
  cinterop from the shutdown path, or continuous mode through `LLVM_PROFILE_FILE` with `%c`. A
  service stops on a signal and never reaches `atexit`, so this is not a detail.
- AC: the rebuilt IR is dumped **from the binary that is measured**, and three numbers are read out
  of it: functions with the profile applied, functions dropped on a CFG hash mismatch, and
  indirect call sites promoted.
- AC (positive control, and the brief's rule made into a check): a profile from a **different**
  program is applied and the hash-mismatch count is near total. A pipeline that reports "applied"
  for a profile that cannot match is reporting on its own bookkeeping.
- AC (second control): the same profile applied through Route A and Route B gives the same applied
  and mismatched counts. Where they differ, Route B is right until shown otherwise.
- AC: arm A1's run-time overhead is recorded and not judged, and if A1 cannot hold the training
  rate the profile is taken at a lower rate and the results say which.
- AC: the effort is timed against the five-day criterion from a recorded start; an overrun is
  written as "not completed" with the reason and the next step starts.
- Anchors: `logs/b-08/`, `ci/pgo/route-b.sh`, `ci/pgo/route-a.patch`,
  `JetBrains/kotlin@v2.4.20!/kotlin-native/backend.native/compiler/ir/backend.native/src/org/jetbrains/kotlin/backend/konan/llvm`.
