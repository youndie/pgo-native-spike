---
id: B-15
title: "Cross-check the ceiling with razves's sampler, as a second implementation"
status: question
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

## Iteration 1 — 2026-09-21. Blocked by the subject, not by the tooling

Everything the item needs works except the one thing it exists for. Full evidence in
`logs/b-15/`.

**Established:**

- **AC (reachability) — the precondition named the wrong host.** It required IPv6 "because that
  host has no IPv4 route"; that is the **bench** pair (B-04). Builds run on the WSL box, which
  reaches `reposilite.kotlin.website` over IPv4. Third stated blocker in this study that cost
  nothing once looked at.
- `io.github.youndie.razves:sampler:0.1.0.33` resolves from reposilite **snapshots**, which xyk
  already declares. Not on Central, not on `releases`, and razves's README quotes `0.1.0.28`,
  which is published nowhere.
- The sampler links and works: an arithmetic probe gave 114 samples, 0 dropped, 100 % of leaves
  named, `BY ORIGIN` = `kotlin 100 %` — razves's own positive control, on a program whose answer
  is known.
- **AC (rebuild) — met.** The patched subject builds at the full pin and **the sampler costs
  22 160 bytes**: 20 191 608 against 20 169 448. The patch is `patches/razves-sampler.py` and
  applies to a copy; it is scaffolding, so unlike B-19 it is not offered to xyk.

**The wall: the sampler kills the subject.** Its timer signal interrupts Ktor's CIO selector in
`pselect`, and **Ktor's native selector does not retry on `EINTR`** — it throws, uncaught, and the
process dies. Same binary, same load, sampler the only difference:

| arm | survived | `EINTR` |
|---|---|---:|
| off | **yes** | 0 |
| 997 Hz | **no** | 1 |
| 97 Hz × 3 runs of 60 s | **no, yes, no** | 1, 0, 1 |

The one 30-second survival at 97 Hz that suggested a lower rate might work was a single run of a
single variant. Three longer runs killed it twice.

**This is not razves's defect.** A `pselect` caller that does not handle `EINTR` is broken for any
process that receives signals at all. razves makes it frequent enough to observe. The transferable
form: **no in-process signal-based profiler can run against Ktor CIO on Kotlin/Native** until that
loop retries, which is also why `perf` — out-of-process, delivering no signals — remains the only
instrument that can answer RQ1 on this subject.

**Nothing published changes.** RQ1's numbers stand; what is missing is the independent check on
them, so the results document's caveat stays true and is now known to be expensive to remove.

## Question — for a person, 2026-09-21

**The second implementation cannot be had on this subject by this route.** Which of these is
worth doing is a judgement about the study's remaining value, not something this loop should
decide:

1. **Drop the cross-check.** RQ1 keeps its caveat, stated plainly: one sampler, one grammar, both
   written here. Cheapest, and the study's conclusions do not rest on RQ1 being exact — A2.3
   dropped the macro arms on a margin of eleven points.
2. **Fix the `EINTR` retry.** The defect is in Ktor's native selector loop, which is upstream and
   outside this brief's non-goals only if somebody decides it is. A retry is a small change, and
   it would unblock every in-process profiler on Kotlin/Native, not just this one — which may be
   worth more than this study's cross-check.
3. **Cross-check on a different subject.** Run razves and `perf` against the RQ2 microbenchmark,
   which has no selector and no signals problem. It checks the *grammar* against an independent
   reader, which is most of the value, but not on the binary RQ1 is about.
4. **Record it in razves** as a known limitation — that it cannot profile a Ktor CIO service on
   Native, and why. razves is our own, and the next person to try this deserves the sentence.

Option 3 is the one that recovers most of the item's value for least effort, and option 4 is
nearly free; they are not exclusive. Option 2 is the one with value beyond this repository.
