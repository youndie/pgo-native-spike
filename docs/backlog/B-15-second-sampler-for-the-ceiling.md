---
id: B-15
title: "Cross-check the ceiling with razves's sampler, as a second implementation"
status: wip
priority: P2
size: M
stage: stage-1-ceiling
blocked_by: [B-07]
---

# B-15 — Cross-check the ceiling with razves's sampler

RQ1's buckets come from one sampler (`perf`) read through one grammar
(`scripts/attribution.py`), and both were written here. razves offers a genuinely independent
second measurement: a different sampler — a C signal handler and a ring buffer linked into the
process — a different symbol reader that parses ELF itself, and its own `BY ORIGIN` table whose
rows are `kotlin`, `kotlin_runtime` and `<outside the binary>`, which is RQ1's boundary drawn by
somebody else's hand.

It also reports what it could not name (`97.0 % of the leaves have a name` in its own README's
example) and what the ring could not hold, which is the reconciliation
[B-06](B-06-attribution-grammar-before-the-ceiling.md) had to supply for itself.

- **The decision and its reason.** Run it as a *check on RQ1*, not as RQ1. Two implementations
  find what one cannot, and a gate this study can be stopped by should not rest on a grammar
  written by the person who wants it to pass.
- The rejected alternative is trusting the agreement of two greps over the same `perf script`
  output, which is one implementation counted twice.
- Not covered: replacing `perf`. The kernel bucket is a third of self CPU on this subject and an
  in-process sampler cannot see it at all, so razves cannot answer RQ1 alone.

- AC: the subject is rebuilt with `io.github.youndie.razves:sampler` linked in, and the rebuild is
  shown to be otherwise identical to the pinned arm — same flags, same allocator, and the size
  delta of the sampler itself stated.
- AC: razves's `BY ORIGIN` self shares are put beside `attribution.py`'s `kotlin:kfun` and
  `runtime` rows for the same workload, and the difference is stated as a number.
- AC: razves's unnamed-leaf percentage and its dropped-sample count are printed. A profile that
  lost samples says so; one that cannot name its leaves is not evidence about which bucket they
  were in.
- AC (the control that makes it a check and not a duplicate): where the two disagree by more than
  the unnamed fraction, the disagreement is chased to a named symbol before either number is used.
- AC: reachability is established first — `reposilite.kotlin.website` must be resolvable **over
  IPv6** from the build host, because that host has no IPv4 route
  ([B-04](B-04-fork-at-the-pinned-tag-and-the-baseline.md)).
- Anchors: `logs/b-15/`, `razves/README.md`, `pgo-native-spike/scripts/attribution.py`,
  `xyk/server/build.gradle.kts`.
