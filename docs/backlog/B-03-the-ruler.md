---
id: B-03
title: "The ruler: A0 against itself, in µs CPU per request, on the two-host stand"
status: open
priority: P0
size: M
stage: stage-0-stand
blocked_by: [B-01]
---

# B-03 — The ruler: A0 against itself, in µs CPU per request

Before any arm is compared, the same binary runs against itself, interleaved, five rounds, and the
spread of that run is the ruler. Everything the brief calls an effect is defined relative to it,
and kill criterion 4 ends the macro half if it is above 5 %.

**This item is the study's main risk, and it costs one day.** Every prior in the portfolio that
resembles the ruler sits at or above the threshold: 2–9 % for the same unit on a JVM, 5–7 % for rps
on this very host pair, 130 % for rps on a four-core host
([research §1.5](../research/research-architecture.md)). No one has ever measured µs CPU per
request for a Kotlin/Native binary here, so the prior sizes the risk and predicts nothing.

- **The decision and its reason.** It runs before the fork is built and before any compiler work,
  because it needs neither and because it can end half the study on its own. The brief already
  orders the ceiling ahead of feasibility for the same kind of reason; this goes one step further
  ([research D4](../research/research-architecture.md)).
- **The unit is amendment A1.1's**: cost per request from the occupancy of the subject's pinned
  cores in `/proc/stat`, with `utime+stime` from `/proc/<pid>/stat` recorded beside it. The JIT
  phase measured the process counter overstating by 6.4–7.2 %, constantly, and wrote the
  replacement into its own research.
- The rejected alternative is rps. On this stack rps at small core counts is a sample rather than
  a property (spread 2.3×), and at high rates it measures the offered concurrency rather than the
  server.
- Not covered: any arm other than A0. Two binaries are not compared here; one binary is compared
  with itself.

- AC: five interleaved rounds of A0 against A0 at the stated offered rate per endpoint, round one
  discarded as warm-up, the within-arm spread printed per endpoint in both estimates.
- AC: the generator's own ceiling is established for each endpoint first — the offered rate at
  which dropped iterations appear — and the stated rate is below it, with the number in the log.
  xyk's stand already does this; the JIT phase's did not.
- AC: the offered / delivered / dropped accounting closes, as it did on xyk's pair. A run whose
  arithmetic does not close is discarded rather than explained.
- AC: `nproc` as observed inside the subject is recorded with every round. The same binary with the
  same four cores of CPU differs by up to ninety times depending on whether they arrive as a quota
  or a cpuset ([research §1.8](../research/research-architecture.md)).
- AC (positive control, and it is the one that makes the ruler a ruler): a deliberately different
  build — the same source with an obviously heavier flag, or the same binary under a second
  concurrent load — is run through the identical protocol and comes out **outside** the ruler. A
  ruler that cannot see a difference anybody can see is measuring the harness.
- AC: the verdict on kill criterion 4 is written the day this closes, whichever way it goes.
- Anchors: `logs/b-03/`, `xyk/bench/run.sh`, `xyk/bench/columns.sh`.
