---
id: B-13
title: "Publish the result, including the parts that were not measured"
status: done
priority: P0
size: M
stage: stage-6-publish
blocked_by: [B-07, B-09, B-10, B-12]
---

# B-13 — Publish the result, including the parts that were not measured

The deliverable: a verdict per research question with its cost in µs of CPU per request, the recipe
as a script, the patch set, and an article for kotlin.website. Green, grey, red and kill outcomes
get the same level of detail, and withdrawn claims stay in the document with the reason they died.

This item closes the backlog. It also runs **if the study is killed**, in exactly the same shape —
the brief requires a stop to be written up with the same care as a result, and every one of the
four likely stops already has its draft in
[research §6](../research/research-architecture.md).

- **The decision and its reason.** One results document, dated, next to the raw output and the
  exact build command for every number in it. A figure without the run that produced it does not
  go in; a retraction is appended and the original is not edited away.
- Nothing goes upstream. The brief's non-goals are explicit: no YouTrack tickets, no pull requests
  to `JetBrains/kotlin` or LLVM, no design proposal. A finding that looks like an upstream bug is
  written down here and left here, and carrying it anywhere is the owner's decision taken after
  this backlog closes.
- The rejected alternative is publishing only if something came out green. The negative result is
  the more likely deliverable and the more useful one: nobody in this portfolio has ever
  attributed a Kotlin/Native service's CPU by bucket, whatever the compiler work turns out to be
  worth.
- Not covered: a Gradle plugin, packaging, or a maintained fork. Non-goals, all three.

- AC: a verdict table — green, grey or red per RQ against the thresholds as declared in
  [BRIEF.md](../../BRIEF.md), with the condition each grey missed.
- AC: every published number names its methodology, has its raw output committed beside it under
  `docs/research/`, and carries the exact build command.
- AC: a "what was not measured" section listing every step recorded as not completed, with the
  reason and the budget it overran.
- AC: the ruler is stated next to every macro number, and any difference under twice the ruler is
  written as "below resolution, effect under N %".
- AC: the recipe is a shell script and a patch set that a reader can run, not a narrative.
- AC: the amendments are reported as amendments — what the brief said, what was changed before the
  first measurement, and why — so that a reader can apply the original thresholds themselves.
- Anchors: `docs/research/`, `logs/`, `ci/pgo/route-b.sh`.

## Iteration 1 — 2026-09-20. Published, and the recipe was the unmet part

**The document was already most of the way there; the AC that was not met was "the recipe is a
shell script and a patch set that a reader can run, not a narrative".** The recipe existed as
prose in six files — BRIEF.md, four backlog items and `logs/b-08/README.md`. It is now
[`recipe/pgo.sh`](../../recipe/pgo.sh) with [`recipe/example.kt`](../../recipe/example.kt), run
end to end on **bench-a**, a host that had built nothing in this study (`logs/b-13/`).

- **The script asserts every step that can fail silently**, and has an `ERR` trap so it cannot
  exit 0 after one fails. Writing it found two such steps immediately: `-Xsave-llvm-ir-directory`
  prints a warning and **exits 0** when the directory does not exist, and the `essentials` LLVM
  bundle a normal install pulls has no `opt` at all.
- **Both load-bearing claims were verified by removing them**, not by the recipe having worked:
  without `-u__llvm_profile_runtime` the binary links, runs, and writes no profile; with the
  stock version object the profile merges `Front-end` and `pgo-instr-use` refuses it.
- **`download.jetbrains.com` is reachable over IPv6** from the bench hosts even though
  `cache-redirector.jetbrains.com` has no AAAA record — which is how the dev bundle got there.
- **The two controls that decide numbers are now in `make check`** (`make controls`).
  `attribution_control.py` already existed and nothing ran it; a control nothing runs is
  indistinguishable from one that does not exist.

**Two things this iteration found that belong to other items**, recorded rather than absorbed:

- **RQ0's two numbers, on the microbenchmark**: 934 functions in the profile, 171 with non-zero
  counters, **170 applied, 0 dropped on a hash mismatch**. So
  [B-21](B-21-rq0-the-two-numbers.md) is no longer three unknowns; it is one, the macro subject,
  which needs [B-22](B-22-replay-the-linker-command.md)'s link. The reader is
  `scripts/profile_applied.py` and it has its own control.
- **[B-23](B-23-flattened-profile-control.md) is moot and was dropped.** Arm A4 is macro and the
  macro arms are gone; and the question A4 asked — is the gain profile-guided or would any
  rebuild move it? — is answered on the micro half by a control already in the data: uniform and
  90/10 come from the **same pair of binaries**, so a rebuild or layout effect would move both.

**What is deliberately not done here.** The item's prose mentions "an article for
kotlin.website". Publishing outside this repository is the owner's call, not the loop's, and the
brief's non-goals put everything upstream out of scope. The results document is written so that
it can become one; nothing was sent anywhere.

**Verdicts at close**: RQ0 grey, RQ1 grey and conditional, RQ2 green on an arm the brief listed
as a control, RQ3–RQ6 dropped by A2.3 on a rule written before the run that decided it. The
largest measured effect in the study is a build flag nobody asked about: the paged allocator,
worth **19.01 % ±2.33 %** of request CPU.
