---
id: B-07
title: "RQ1 — the ceiling: what share of self CPU is Kotlin code"
status: done
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

---

## Findings — 2026-09-20

# RQ1 is **GREY**

Green needed at least 40 % on a majority of endpoints; the highest is 35.38 % and **no endpoint
reaches 40 %**. Red needed under 20 % on *every* endpoint; **two are above it**. Neither
condition is met, which the brief says is grey by construction.

Per the brief: RQ3 and RQ4 therefore **run**, and the write-up carries the ceiling next to every
macro number.

| endpoint | rate | **Kotlin self** | Kotlin anywhere | kernel | runtime | libc & native | Rust |
|---|---:|---:|---:|---:|---:|---:|---:|
| `GET /health/live` | 200 | **35.38 %** | 63.52 % | 25.60 % | 14.01 % | 23.99 % | 0.49 % |
| `POST /hooks/{id}` | 200 | **20.61 %** | 34.93 % | 32.20 % | 12.85 % | 31.21 % | 2.47 % |
| `GET /api/events` | 200 | **17.27 %** | 28.96 % | 15.59 % | 23.42 % | 41.80 % | 2.07 % |
| `GET /journal` | 40 | **14.92 %** | 25.15 % | 13.00 % | 31.32 % | 38.77 % | 1.96 % |

Every run: `nproc` 4 as the runtime sees it, zero failed requests, **zero unresolved samples**
against the brief's 5 % discard rule, and each table reconciles to its sample count.

### The shape of it: the more the endpoint does, the less of it is Kotlin

`/health/live` parses nothing, touches no database and serialises nothing — and it has **twice**
the Kotlin share of the endpoint that renders a page. The gradient runs the wrong way for this
study: **PGO's territory shrinks exactly where the service does real work**, because real work is
allocation, the collector and libc.

What the non-Kotlin majority actually is, by symbol:
`kotlin::gc::internal::MainGCThread<CmsGCTraits>::PerformFullGC` (4.4–11.3 % on its own),
`_int_malloc`, `__libc_calloc`, `malloc_consolidate`, `kotlin::alloc::CustomAllocator::CreateObject`.
**It is the allocator and the collector**, which is precisely the ceiling the brief's opening
paragraph worried about, measured rather than assumed.

### The arithmetic this hands to RQ3, which is the useful half of a grey gate

The brief's own sizing: a 5–15 % PGO return on the code it touches, at a 20 % bucket, is **1–3 %
of a request** — and it adds "which no ruler on these hosts resolves". Against
[B-03](B-03-the-ruler.md)'s measured ruler the macro bar is `max(5 %, 2 × ruler)` = **9.3 % at
four counted rounds, 5 % at eight**. So on the three endpoints that do work, the expected effect
is **at or below the floor even in the best case**, and only `/health/live` — the endpoint that
does nothing — sits where PGO could in principle clear it.

This is not a verdict on RQ3 and does not pre-empt [B-10](B-10-rq3-rq4-the-macro-arms.md). It is
the number that item has to be read against.

### A saturated endpoint reports a much higher Kotlin share, and that nearly became the answer

`/journal` at the pinned 200 rps was **saturated** — 142 delivered of 200 offered, p50 1.3 s — and
reported **55.55 % Kotlin**. The same endpoint at 40 rps, clean, p50 7.7 ms, reports **14.92 %**.

A factor of 3.7 on the gate's own quantity, from nothing but load. Taken at face value the
saturated run would have put two of four endpoints above 40 % and made the gate look like a near
miss on green instead of what it is. **The brief fixes an offered rate per endpoint and says
nothing about saturation**, and an RQ1 number is only meaningful from an unsaturated run —
because under saturation the queueing machinery that backs up is Kotlin, and it displaces exactly
the libc and collector work the gate is trying to size.

### H7 — not confirmed

H7 asked whether the unexplained four-visible-core collapse
([research §1.8](../research/research-architecture.md)) shows up here as kernel or runtime time.
Kernel is 13.0–32.2 % and is **not** the dominant bucket on any endpoint; the largest single
bucket on three of four is libc and native, and its content is the allocator. So the gap is not
predominantly kernel time. That is a negative result about H7 and not an explanation of the
collapse, which remains open.

### Two more defects, and the gate number survived both

1. **The line parser.** `perf script -F ip,sym,dso` output was split on whitespace and field 2
   taken as the symbol. perf **demangles**, and a demangled C++ name has spaces — so
   `void kotlin::gc::…::PerformFullGC(long)` arrived as the symbol `void`.
2. **The grammar's `startswith`.** Even parsed correctly, `void kotlin::…` does not *start with*
   `kotlin::`, so a return type defeated the rule. Now normalised to the qualified name.

Together these moved 4–12 percentage points per endpoint **from the runtime bucket into libc**.
They did not move `kfun:` by a single sample, because Kotlin symbols carry no return type — so
**the gate's verdict is unaffected and the supporting columns were wrong until now**.

**The control did not catch either one**, and the reason is worth more than the bugs: it handed
`bucket()` symbols that were already split, so it tested the grammar and never the parser. Three
whole-line cases have been added, and the control is now 14 for 14.

### Not covered

- **The GC log the AC asks for.** `-Xruntime-logs=gc=info` is a compile-time flag and the pinned
  binary does not carry it, so it needs a rebuild — and **`bench-a` cannot rebuild xyk**:
  `reposilite.kotlin.website`, which serves the sborka catalog the build resolves its compiler
  from, is IPv4-only and the host has no IPv4 route. Same root cause as
  [B-04](B-04-fork-at-the-pinned-tag-and-the-baseline.md). The collector's *share* is measured
  here by symbol (4.4–11.3 % in `PerformFullGC` alone); its pause and sweep times are not.
- **The inclusive column is a lower bound.** Between 16.6 % and 34.0 % of stacks have no callers
  recorded — optimised Kotlin/Native omits frame pointers — and a stack of depth one cannot show
  Kotlin above its leaf. `--call-graph dwarf` would fix it and costs an order of magnitude in
  file size.
- **One round per endpoint.** RQ1 is a share rather than a difference, and shares are proportions
  within one process, but a second round per endpoint would cost twenty minutes and is not in
  this run.
