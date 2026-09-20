---
id: B-01
title: "Pin every row of the fixed setup, and close the amendment window"
status: wip
priority: P0
size: S
stage: stage-0-stand
---

# B-01 — Pin every row of the fixed setup, and close the amendment window

The brief says a range such as "Kotlin 2.x" is not a pin, and then leaves four rows as
descriptions rather than numbers: the Kotlin release "the stand already carries", the LLVM
revision "that Kotlin/Native release bundles", "one Kotlin/Native Ktor service", and "the two-host
protocol of the JIT phase". Three of the four resolved to something other than the obvious reading
([research §1.1](../research/research-architecture.md), §1.4), and one of them — the fork tag —
would have failed kill criterion 2 for a reason nobody would have looked for.

- **The decision and its reason.** The pins go in [BRIEF.md](../../BRIEF.md) as a table, with the
  artefact each was read out of, and the five amendments go in beside them. Written before the
  first measurement, because a threshold or a pin that moves afterwards is worth nothing — the
  rule the brief states and the JIT phase's own experience both say so.
- The rejected alternative is pinning as you go, one row per item. It is how "Kotlin 2.4.10", the
  number sborka builds *itself* with, becomes the fork tag.
- Not covered: the offered rate per endpoint, which is a number and not a version, and comes out
  of [B-03](B-03-the-ruler.md) with the generator ceiling beside it.

- AC: BRIEF.md carries a pins table in which every row names the file or coordinate it was read
  from, and no row is a range.
- AC: the five amendments are in BRIEF.md with a date and the measurement that motivated each; the
  original brief text below them is byte-identical to the one received, headings aside, and the
  demotion is stated.
- AC (the control that matters): **no amendment relaxes a threshold.** The prior says kill
  criterion 4 is the likeliest exit ([research §1.5](../research/research-architecture.md)); an
  amendment that widened the ruler today would be exactly the move the rule forbids. If a
  threshold turns out badly chosen, that is a stated limitation in the write-up beside the number
  it affected.
- AC: the subject's build options are in the pins table — the allocator property and the
  static-link setting — because they move RQ1's denominator and RQ6's number.
- Anchors: `pgo-native-spike/BRIEF.md`, `xyk/server/build.gradle.kts`,
  `xyk/gradle/libs.versions.toml`.
