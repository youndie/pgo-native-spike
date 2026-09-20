---
id: B-10
title: "RQ3 and RQ4 — arms A0, A2, A3 and A4 on the service"
status: open
priority: P0
size: L
stage: stage-4-macro
blocked_by: [B-07, B-08]
---

# B-10 — RQ3 and RQ4: the macro arms on the service

The question the study exists to answer, and the one most likely never to be asked: it runs only
if RQ1 is not red, and the macro half runs only if the ruler cleared kill criterion 4
([B-03](B-03-the-ruler.md)). If RQ1 is grey it runs anyway, and the write-up carries the ceiling
next to every macro number.

RQ3 is A2 over A0 — the profile applied to Kotlin code. RQ4 is A3 over A2 — what applying it to the
runtime bitcode adds, where "the runtime" is defined by owning module and not by mangling
(amendment A1.4, [research §1.9](../research/research-architecture.md)). A4 is a profile from an
unrelated workload, and it is what separates "PGO helps" from "any rebuild moves the number".

- **The decision and its reason.** Arms interleaved, five rounds each, the within-arm spread
  printed beside every between-arm difference. A difference under twice the ruler is reported as
  "below resolution, effect under N %", with N stated — never as zero.
- The rejected alternative is reporting the best round per arm, or reporting rps. On this stack rps
  at small core counts is a sample rather than a property.
- Not covered: changing the allocator, the collector or anything else to make room for the effect.
  Every arm carries the subject's shipping build options.

- AC: µs CPU per request per arm and per endpoint, in amendment A1.1's unit, with `utime+stime`
  recorded beside it and the ruler from [B-03](B-03-the-ruler.md) printed on the same page.
- AC: every arm's row carries its lever-engaged counts — profile applied, profile dropped on hash
  mismatch, sites promoted — read from that arm's own binary. A null over a lever nobody proved
  was connected is not a result.
- AC (kill criterion 5): **A4 is within the ruler of A0.** If a profile from an unrelated workload
  gives the same macro gain as the trained one, the gain is not profile-guided; macro work stops
  and the effect is reported as rebuild and layout noise.
- AC: `nproc` as observed inside the subject, and the generator's ceiling for the endpoint, are
  recorded with every round.
- AC (positive control): a build with an obviously heavier flag is run through the same protocol
  and lands outside the ruler, on the same day as the arms. A protocol that cannot see a
  difference anybody can see turns every arm into a null.
- AC: the three-day budget for RQ3 and RQ4 together is timed from a recorded start.
- Anchors: `logs/b-10/`, `xyk/bench/run.sh`, `xyk/server/build.gradle.kts`.
