---
id: B-13
title: "Publish the result, including the parts that were not measured"
status: open
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
