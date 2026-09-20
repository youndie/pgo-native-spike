---
id: B-17
title: "RQ1, second point: each endpoint at 50-70 % of its own saturation"
status: wip
priority: P0
size: M
stage: stage-1-ceiling
blocked_by: [B-16]
---

# B-17 — RQ1's second point, at a rate chosen by rule

[B-07](B-07-rq1-the-ceiling.md) measured the ceiling at one rate per endpoint and found that the
rate changes the answer: `/journal` read **55.55 %** Kotlin saturated and **14.92 %** clean, a
factor of 3.7 on the gate's own quantity. The brief fixes a rate and never says how to choose it.
Amendment A2.2 now does, and this item takes the point it names.

The other end of the range is the reason a second point is needed rather than a re-run: **200 rps
on a four-core box is close to idle**, and a near-idle server spends its time being woken up. That
inflates the kernel bucket and deflates everything else, exactly as saturation inflates Kotlin.
The number that decides this study sits between the two ends, and neither existing point is it.

- **The decision and its reason.** 50–70 % of each endpoint's own saturation rate, established
  per endpoint rather than shared, because the endpoints' knees differ by an order of magnitude
  (ingest ~350 rps, `/journal` under 40).
- **The rule that decides Route A is declared in [BRIEF.md](../../BRIEF.md) A2.3 before this run**:
  if **Kotlin self plus runtime** stays under 40 % on every work endpoint, Route A, RQ5 and RQ6
  are dropped. On B-07's numbers, at the wrong rate, it would not fire — 40.69 %, 46.24 %,
  33.46 % — and that is recorded so the rule cannot read as having been chosen for its answer.
- The rejected alternative is averaging the saturated and idle points. They are not two samples
  of one quantity; they are two different regimes.
- Not covered: a verdict on RQ3. This sizes the ceiling, it does not measure an effect.

- AC: each endpoint's saturation rate is established first — the offered rate at which delivered
  falls below offered — and the run rate is 50–70 % of it, stated.
- AC: **every run is shown unsaturated**: delivered equals offered to within the generator's own
  error, and p50 is on the flat part of the curve. A run that is not is discarded, not adjusted.
- AC: one `--call-graph dwarf` capture per endpoint. B-07's inclusive column is a lower bound
  because 16.6–34.0 % of stacks had no callers — optimised Kotlin/Native omits frame pointers —
  and dwarf fixes it. File size is not a concern for a 30-second window.
- AC: the GC log from [B-16](B-16-unblock-off-host-builds.md)'s logging build, beside the buckets.
- AC: **Kotlin self plus runtime** is reported per endpoint as its own column, because that is the
  quantity A2.3's rule is written against.
- AC: the dwarf capture names **who calls libc malloc** — Ktor and kotlinx-io buffers, the
  runtime's C++ containers, SQLite, or the Rust. That is [B-18](B-18-allocator-probe.md)'s input
  and the study's most likely real finding.
- AC (positive control): the arithmetic control from B-07 is re-profiled through the dwarf
  pipeline and still reports above 80 % Kotlin. A change of capture mode is a change of
  instrument.
- Anchors: `logs/b-17/`, `pgo-native-spike/bench/ceiling.sh`, `pgo-native-spike/scripts/ceiling_report.py`.
