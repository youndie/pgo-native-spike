---
id: B-12
title: "RQ6 — what it costs: binary size per owner, build time, A1's overhead"
status: dropped
priority: P2
size: S
stage: stage-5-cost
blocked_by: [B-08, B-17]
---

# B-12 — RQ6: what it costs

> **Conditional as of 2026-09-20 ([BRIEF](../../BRIEF.md) A2.3 and A2.4).** RQ6 is dropped if
> Kotlin self plus runtime stays under 40 % on every work endpoint at the rate
> [B-17](B-17-rq1-second-point.md) fixes, and dropped again if
> [B-10](B-10-rq3-rq4-the-macro-arms.md)'s best-case probe comes back null. It is kept in the
> backlog rather than deleted, because an item that vanished records nothing.

Half a day. Binary size of A2 and A3 against A0, measured per owner with `razves`; green is within
+5 % of A0, red is above +15 %. Build time and arm A1's run-time overhead are recorded and **not
judged** — the brief is explicit, and an item that quietly started judging them would be answering
a question nobody asked.

- **The decision and its reason.** Per owner rather than as one number, because "the binary grew
  3 %" says nothing about whether the growth is the promoted call sites, the profile metadata or
  the runtime, and only the first of those is the thing being bought.
- **razves output is data, not a verdict.** It is this portfolio's own tool measuring this
  portfolio's own binaries; its reconciliation identity and its unattributed and unparsed rows are
  printed rather than folded away.
- The rejected alternative is `bloaty` or `llvm-size`. Neither is in the Kotlin/Native toolchain
  ([research §1.2](../research/research-architecture.md)), and razves exists because of that.
- Not covered: doing anything about the size. A red RQ6 is a reported cost, not a task.

- AC: bytes per owner for A0, A2 and A3 from one `razves` run each, with the reconciliation
  identity printed and every byte of the file charged to exactly one row.
- AC: all three binaries are **linked the same way**. A cross-linkage-mode comparison carries the
  linker's own ~0.9 MB and reports it as PGO.
- AC: build time and A1's overhead are in the log with the arms they belong to, and no verdict is
  attached to either.
- AC (positive control): the A0-against-A0 size comparison is zero. A size pipeline that reports a
  delta between a binary and itself is reporting on its own reproducibility, which is
  [B-05](B-05-six-unknowns-of-the-release-pipeline.md)'s finding and not RQ6's.
- Anchors: `logs/b-12/`, `razves/README.md`, `xyk/server/build.gradle.kts`.

---

## Dropped — 2026-09-20, by the rule that was declared before the measurement

[BRIEF](../../BRIEF.md) A2.3: *"if Kotlin self plus runtime stays under 40 % on every work
endpoint, Route A, RQ5 and RQ6 are dropped."*
[B-20](B-20-ceiling-on-the-paged-allocator.md) measured **28.4–28.6 % on all three**, on the
allocator build that was the last plausible way for the number to come out higher.

RQ6 is therefore dropped, not deferred. The rule was written down before the run it decides and
its answer on the then-available data was recorded beside it, so this is the rule working rather
than a conclusion looking for one.

**What would re-open it:** a subject whose Kotlin plus runtime share is materially higher, or a
PGO effect large enough to matter at 28 %. The per-call bound in the results document says the
second is not this mechanism.
