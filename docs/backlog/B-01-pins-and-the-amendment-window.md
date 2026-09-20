---
id: B-01
title: "Pin every row of the fixed setup, and close the amendment window"
status: done
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

---

## Findings — 2026-09-20

**Done.** Four acceptance criteria, and three of them found something.

### AC1 — the pins table: two rows were not pins

| | |
|---|---|
| `Subject build options` | said "xyk's shipping release build: `-Pxyk.allocator=paged-off`, the repository's default static-link setting". The second half is a description, not a value — exactly what this item exists to eliminate. And there are **four** axes in that build, not two |
| `Fork tag` | cited "the row above" as its source, which is a derivation rather than somewhere a reader can check |

Both corrected. `xyk/server/build.gradle.kts` lines 28–44 declare `xyk.httpClient` (default
`false`), `xyk.staticLink` (default `false`), `xyk.allocator` (default `paged-off`) and
`xyk.outbound` (default `real`). The pin is
`-Pxyk.httpClient=false -Pxyk.outbound=real -Pxyk.staticLink=true -Pxyk.allocator=paged-off`.

**Two of those differ from the build's own defaults, deliberately.** The arm xyk's two-host
measurement was taken on is the ingest-only build *statically linked*; pinning the defaults would
have meant that none of the priors this study leans on — the generator ceiling, the round-to-round
spread — describe the binary it runs. Recorded with its cost in
[research §1.10](../research/research-architecture.md).

**The judgement in that pin, stated rather than buried:** `httpClient=false` removes the delivery
half of the product, and the delivery path is where a service of this shape keeps most of its
polymorphic dispatch — which is the mechanism the whole study rests on. The pin may therefore
understate what PGO is worth here. It is still the pin, for the three reasons in research §1.10,
and it is reversible until the first measurement. This is the one row a reader may reasonably want
changed.

### AC2 — the received brief is byte-identical, and the check does not survive the week

Verified by restoring the embedded copy — undoing the heading demotion and nothing else — and
comparing with the file as received:

| | |
|---|---|
| received | 18 849 bytes, `sha256 77d8480c…859a77` |
| restored from BRIEF.md | 18 849 bytes, same digest |
| difference | none |

So the demotion was the only transformation, as claimed. **But the check needed a file in the
owner's `~/Downloads`, which is not in this repository and will not survive.** From the day it is
deleted, "unedited" is an assertion nothing here can support. The digest is now recorded in
BRIEF.md so anyone still holding the file can repeat the check in one command; making it checkable
from the repository alone is [B-14](B-14-make-the-freeze-checkable-from-the-repo.md), raised rather
than folded in.

### AC3 — two amendments moved RQ1 towards green without touching a number

This is the criterion that did the most work, and it caught its own author.

- **A1.3** widens the Kotlin bucket from `kfun:` to all twelve Kotlin prefixes. That can only
  *enlarge* the bucket, so it moves RQ1 towards its 40 % green and away from its 20 % red — while
  leaving both numbers untouched and therefore looking like a definition rather than a
  relaxation. It is a correction of a genuine mis-specification (under the literal rule, `kclass:`
  and `kvar:` symbols fall into "libc and other native", which is wrong), so it stays — with the
  `kfun:`-only share now published beside the widened one, and the verdict stated against both.
- **A1.5** lets the kernel row go missing when `perf` will not run. Removing a bucket from the
  denominator inflates every other bucket: at a kernel share of a third, by about 1.5×. Now
  qualified — **with the kernel row missing, RQ1 cannot be reported green, grey at best.**

Neither was noticed when the amendments were written. Both were found by taking this item's own
acceptance criterion literally and checking the five amendments against it one at a time, which is
the argument for writing the criterion down before doing the work rather than after.

### AC4 — no amendment relaxes a threshold

True as it now stands, and it was not true when this item opened. A1.1, A1.2 and A1.4 do not touch
RQ1's arithmetic: A1.1 changes an instrument, A1.2 a host protocol, A1.4 moves `sqlx4k`'s Rust
between two buckets neither of which is the Kotlin one. A1.3 and A1.5 did, and are fixed above.

### Not covered

The amendment window is declared closed as of the first measurement, not as of this item — nothing
has been measured yet, so a sixth amendment is still legitimate until [B-03](B-03-the-ruler.md) or
[B-02](B-02-can-the-subject-host-be-profiled.md) takes a number. After that, a threshold that turns
out badly chosen is a stated limitation in the write-up, not an edit.
