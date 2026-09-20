---
id: B-09
title: "RQ2 — does indirect call promotion fire on Kotlin dispatch, and what is it worth"
status: open
priority: P0
size: M
stage: stage-3-mechanism
blocked_by: [B-08]
---

# B-09 — RQ2: does indirect call promotion fire on Kotlin dispatch

The one LLVM pass the whole case rests on. Indirect call promotion records the top targets of every
indirect call, then emits a guarded direct call the inliner can see through — speculative
devirtualisation without deoptimisation, which Kotlin/Native has no other source of. Green needs
promotion and inlining visible in the IR at the benchmark's sites **and** the micro effect met on
both dispatch shapes; virtual and interface calls are priced separately.

- **The decision and its reason.** The sites must have several implementors reachable, so that the
  compiler's own closed-world devirtualisation cannot resolve them, and one receiver at run time.
  A site the compiler already devirtualises measures nothing about PGO.
- One day per dispatch shape, per the brief's budget, and the shapes are priced separately because
  a vtable call and an itable call are different work and a single number would hide which one
  moved.
- The rejected alternative is measuring this on the service first. The microbenchmark prices the
  mechanism; only RQ3 says whether it matters, and running them in the other order gives a null
  with no way to tell mechanism from magnitude.
- Not covered: whether any of this survives on the service. That is
  [B-10](B-10-rq3-rq4-the-macro-arms.md).

- AC: kotlinx-benchmark on the native target, ns/op per arm, with non-overlapping 99 % confidence
  intervals and at least a 10 % change for the micro effect to count.
- AC: IR excerpts showing the promotion at the benchmark's own sites, read from the measured
  build, plus `opt` statistics and pass remarks giving promoted sites by function.
- AC (control of known outcome 1): eight receivers in **uniform rotation** gain nothing, because
  no target dominates.
- AC (control of known outcome 2): eight receivers at **90/10** gain most of what the
  single-receiver case gains.
- AC: if either control comes out the other way, RQ2's numbers are not used until the reason is
  found, and kill criterion 6 starts its two-day clock.
- AC (unit control): each microbenchmark arm has a unit control beside it — an arm that performs
  exactly the one operation being priced and nothing else — so that a ns/op difference is
  attributable to the dispatch and not to the loop around it.
- AC (the known-order pair): a variant that does everything another does plus one step runs beside
  the set. If it comes out cheaper, the run is discarded and the stand is fixed before anything is
  read.
- Anchors: `logs/b-09/`, `bench/src/nativeMain/kotlin/DispatchBench.kt`.
