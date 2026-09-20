---
id: B-07
title: "RQ1 — the ceiling: what share of self CPU is Kotlin code"
status: wip
priority: P0
size: M
stage: stage-1-ceiling
blocked_by: [B-03, B-06]
---

# B-07 — RQ1: the ceiling, and where the CPU actually goes

The gate. Green is at least 40 % of self CPU in the Kotlin bucket on a majority of endpoints; red
is under 20 % on every endpoint, and red stops RQ3 and RQ4. The brief's own arithmetic: at a 40 %
bucket a 5–15 % return on the code PGO touches is 2–6 % of a request, which can clear the macro
threshold; at 20 % it is 1–3 %, which no ruler on these hosts resolves.

There is **no usable prior for this number** ([research §1.6](../research/research-architecture.md)).
The portfolio's often-quoted "user code is 4 % of CPU" is a JVM measurement of a narrower bucket —
application code only, against RQ1's application *plus libraries plus stdlib* — and must not be
cited here in either direction.

- **The decision and its reason.** Self samples, because PGO acts where self time is spent. The
  brief's own rule, kept, along with its own admission that self attribution **understates** the
  ceiling: a sample in the allocator reached from Kotlin code counts as runtime, though a promoted
  and inlined call might have removed the allocation's cause. The bias points towards stopping, so
  a red RQ1 is reported with the inclusive share of Kotlin callers beside it.
- The rejected alternative is owner attribution as the headline. It answers a different question —
  whose code asked for this work — and it is the question the JIT phase answered, which is how its
  number came to be quoted for this one.
- Not covered: doing anything about what the table shows. Changing the allocator or the collector
  is a different study by the brief's own non-goals.

- AC: the five-bucket table per endpoint on A0 at the stated offered rate, with the unresolved row
  shown; a run above 5 % unresolved is not used.
- AC: the GC picture beside it — `-Xruntime-logs=gc=info`, collections and pause and sweep time
  per window — so the runtime bucket has a mechanism next to its share.
- AC: the inclusive share of Kotlin callers is reported beside the self share, whichever verdict
  comes out, because the gate's bias is known and the reader should see what the rule cost.
- AC: `nproc` as observed inside the subject is recorded. H7 asks whether the unexplained
  four-visible-core collapse ([research §1.8](../research/research-architecture.md)) shows up here
  as kernel or runtime time; this table is the first attribution of that gap anyone in this
  portfolio will have.
- AC (positive control): a synthetic endpoint that is known to be almost entirely Kotlin
  arithmetic is profiled through the same pipeline and comes out in the Kotlin bucket above 80 %.
  An attribution that reports 5 % Kotlin for everything looks exactly like a red gate.
- AC: the verdict against the declared thresholds is written the day this closes, and if it is red
  the write-up states that RQ3 and RQ4 are not started and RQ0 and RQ2 continue as a toolchain
  study making no performance claim.
- Anchors: `logs/b-07/`, `xyk/server/build.gradle.kts`, `razves/README.md`.
