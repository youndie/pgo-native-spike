---
id: B-10
title: "RQ3 and RQ4 — arms A0, A2, A3 and A4 on the service"
status: dropped
priority: P0
size: L
stage: stage-4-macro
blocked_by: [B-07, B-08, B-22]
---

# B-10 — One best-case macro probe: A3 against A0

> **Re-scoped 2026-09-20 by [BRIEF](../../BRIEF.md) A2.4.** Not four arms — **one probe**, and it
> is the best case rather than the main effect.
>
> - **A3 against A0**, through Route B, on the **most favourable endpoints**, at **eight** counted
>   rounds (A2.1), where the bar is the brief's 5 % floor rather than 9.3 %.
> - **A3 is the upper bound on the whole idea**, because it covers Kotlin code *and* the C++
>   runtime — and the C and C++ prior of a 5–15 % return genuinely applies to the runtime, which
>   is where RQ1 found the CPU.
> - **A null here stops the study.** A2 cannot succeed where A3 fails, and A4 exists only to
>   explain a positive result, so neither is run unless this probe is positive.
> - If it is positive, the brief resumes as written.

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

---

## Blocked on B-22 — 2026-09-20

Recorded as a dependency because it is one. Iteration 1 established that the link fails without
the native dependency graph, and that supplying archives by hand is unbounded — librdkafka's
five only moved the failure to `sqlx4k`.
[B-22](B-22-replay-the-linker-command.md) replays the linker command the build prints, which is
what the brief said to do and what makes this item buildable.

Until then the picking rule would hand this item to a loop that cannot finish it, and the loop
would find that out by spending an iteration on it.

---

## Dropped — 2026-09-20

A2.3's drop rule fired on [B-20](B-20-ceiling-on-the-paged-allocator.md): Kotlin self plus
runtime is 28.4–28.6 % on every work endpoint, on both allocator builds. **Route A is dropped,
and with it this probe** — A3 is the upper bound on what PGO can touch, and 28 % of a request is
not a bound worth spending three days of linker work to measure against a 5 % floor.

The linker obstacles this item found stay documented and
[B-22](B-22-replay-the-linker-command.md) stays open at P0, because the replayed-link recipe is
worth having whether or not this probe runs — it is what any future arm on this subject needs.

**What would re-open it:** B-22 landing cheaply, plus a reason to believe 28 % can yield 5 %.
