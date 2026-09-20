---
id: B-18
title: "The allocator probe: LD_PRELOAD jemalloc or mimalloc, outside the verdicts"
status: open
priority: P2
size: S
stage: stage-1-ceiling
blocked_by: [B-17]
---

# B-18 — The allocator probe, logged outside the verdicts

RQ1 found that the largest single bucket on three of four endpoints is libc, and that its content
is `_int_malloc`, `__libc_calloc` and `malloc_consolidate` — **glibc** functions, in a binary that
carries Kotlin/Native's own allocator. Something is calling libc malloc heavily.

`PerformFullGC` alone is 4.4–11.3 % on top of that. Together the allocator and the collector are
a larger share of this service's CPU than the Kotlin code PGO can touch.

- **The decision and its reason.** An `LD_PRELOAD` of jemalloc or mimalloc is **one hour and no
  compiler work**, and its plausible effect is larger than the best case for PGO. Not doing it
  because it is not in the brief would be letting the document choose the finding.
- **It is logged outside the verdicts.** Allocator changes are an explicit non-goal
  ([BRIEF.md](../../BRIEF.md)), so this produces no RQ verdict and does not enter the verdict
  table. It goes in the write-up as a pointer, and it is the natural RQ1 of a different study.
- The rejected alternative is changing the Kotlin/Native allocator option, which is a rebuild, a
  different binary and a real arm — this is a preload and changes nothing about the subject.
- Not covered: deciding anything. A number here is a reason to write a brief, not a reason to
  ship a flag.

- AC: the same endpoints at the same rates as [B-17](B-17-rq1-second-point.md), with and without
  the preload, through [B-03](B-03-the-ruler.md)'s protocol at eight counted rounds so the result
  can be read against the ruler.
- AC: the preload is shown to have taken effect — the malloc symbols in a profile come from the
  preloaded library and not from glibc. **A preload that silently did not load produces exactly
  the null this probe might otherwise report.**
- AC: the result is reported as µs of CPU per request against A0, with the ruler beside it, and
  **no RQ verdict attached**.
- Anchors: `logs/b-18/`, `pgo-native-spike/bench/ruler.sh`.
