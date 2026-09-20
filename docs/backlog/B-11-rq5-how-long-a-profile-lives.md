---
id: B-11
title: "RQ5 — how long a profile lives"
status: dropped
priority: P1
size: M
stage: stage-5-cost
blocked_by: [B-10, B-17]
---

# B-11 — RQ5: how long a profile lives

> **Conditional as of 2026-09-20 ([BRIEF](../../BRIEF.md) A2.3 and A2.4).** RQ5 is dropped if
> Kotlin self plus runtime stays under 40 % on every work endpoint at the rate
> [B-17](B-17-rq1-second-point.md) fixes, and dropped again if
> [B-10](B-10-rq3-rq4-the-macro-arms.md)'s best-case probe comes back null. It is kept in the
> backlog rather than deleted, because an item that vanished records nothing.

A recipe nobody can operate is not a recipe. The profile is applied to the three next real commits
of the subject, and separately to a workload it was not trained on. Green retains at least two
thirds of the RQ3 effect in both tests; red is under one third in either.

This question is conditional on something [B-05](B-05-six-unknowns-of-the-release-pipeline.md)
answers: if two builds of the same source do not produce identical IR at the instrumentation point,
profiles are lost to hash and name mismatches before the first real commit is even applied, and
RQ5's answer is about the build system rather than about the profile.

- **The decision and its reason.** Real commits of the subject, not synthetic edits, because the
  question is operational: how often would somebody have to retrain. A synthetic edit answers how
  fragile the hash is, which [B-05](B-05-six-unknowns-of-the-release-pipeline.md) already covers.
- The rejected alternative is a time-based claim ("a profile lasts a month"). Commits, not days —
  the profile does not know what day it is.
- Not covered: retraining automation, which is packaging and a non-goal.

- AC: the RQ3 effect re-measured on each of the three next real commits, same protocol, same ruler,
  with the retained fraction stated per commit.
- AC: the same applied to an untrained workload shape, with the shape described.
- AC: the hash-mismatch count per commit is reported beside the retained fraction, because a
  profile that stopped working and a profile that stopped applying are different findings.
- AC (positive control): the retention protocol is run with the profile applied to the commit it
  was trained on, and returns the full RQ3 effect. A protocol that returns one third for
  everything, including its own training commit, is measuring itself.
- AC: the two-day budget is timed from a recorded start.
- Anchors: `logs/b-11/`, `xyk/server/build.gradle.kts`.

---

## Dropped — 2026-09-20, by the rule that was declared before the measurement

[BRIEF](../../BRIEF.md) A2.3: *"if Kotlin self plus runtime stays under 40 % on every work
endpoint, Route A, RQ5 and RQ6 are dropped."*
[B-20](B-20-ceiling-on-the-paged-allocator.md) measured **28.4–28.6 % on all three**, on the
allocator build that was the last plausible way for the number to come out higher.

RQ5 is therefore dropped, not deferred. The rule was written down before the run it decides and
its answer on the then-available data was recorded beside it, so this is the rule working rather
than a conclusion looking for one.

**What would re-open it:** a subject whose Kotlin plus runtime share is materially higher, or a
PGO effect large enough to matter at 28 %. The per-call bound in the results document says the
second is not this mechanism.
