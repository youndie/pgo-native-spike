---
id: 2026-09-20-instrumentation-pgo
title: Instrumentation PGO for Kotlin/Native — results
type: research
status: active
date: 2026-09-20
---

# Instrumentation PGO for Kotlin/Native — results

**Interim.** Five of the seven research questions have verdicts. The macro half is not finished
and is reported as not measured rather than estimated. Every number here has a backlog item, a
log directory and a command behind it; nothing is carried over from another project or inferred
from a prior.

The pre-registration is [BRIEF.md](../../BRIEF.md), including three sets of amendments and the
reason each was made. The evidence this study started from is
[research-architecture.md](research-architecture.md).

## Verdict table

| RQ | Question | Verdict | |
|---|---|---|---|
| **RQ0** | Can a Kotlin/Native release binary write a `.profraw` that merges, and can the toolchain apply the resulting `.profdata`? | **GREY** | the mechanism works, but green was defined *on the macro subject* and this is the microbenchmark — and the two numbers the threshold names were never computed |
| **RQ1** | What share of self CPU is Kotlin code? | **GREY**, and **conditional on a build property** | 13.84–35.38 % across four endpoints — measured on a binary that opts out of the paged allocator, which puts libc in the denominator |
| **RQ2** | Does indirect call promotion fire on Kotlin dispatch, and what is it worth? | **GREEN**, on an arm the brief listed as a control | promotion and inlining in the IR; −11.2 % itable and −12.6 % vtable at 99 % confidence **on 90/10**. The pre-registered single-receiver case came in at −7.9 % and did not separate |
| **RQ3/RQ4** | Macro effect on the service | **NOT MEASURED** | Route B reaches the service's compiler and fails at its linker, twice |
| **RQ5** | How long does a profile live? | **NOT MEASURED** | conditional on RQ3 |
| **RQ6** | What does it cost in binary size? | **NOT MEASURED** | conditional on RQ3 |
| — | The ruler | **2.92 %** per paired round | ±4.64 % at four counted rounds, ±2.44 % at eight |

**Kill criterion 2 is moot** — it validates a fork as a baseline and there is no fork. Criteria 1,
3, 4, 5 and 6 did not fire.

## The ceiling was measured on a binary that opts out of the fast allocator

**This qualification comes first because it can invalidate the study's headline.** `pagedAllocator`
is a Kotlin/Native binary option whose default is `true`; **the pinned build sets it to `false`**.
RQ1 is a *share*, and the libc bucket it pushes into the denominator is 26–46 % of samples. So
the sentence "the mechanism has nowhere to pay off here" is conditional on a build property, not
a statement about Kotlin/Native.

**Why the build sets it, measured by the subject's own repository** (`xyk/server/build.gradle.kts`,
64 MiB limit, ten interleaved rounds):

| allocator | survived the limit | ingest throughput |
|---|---|---|
| `fixedBlockPageSize=16` | **1 / 10** | 437 rps |
| paged off (what the pin uses) | **10 / 10**, 54.9–65.7 MB | 379 rps |

The mechanism is that Kotlin/Native keeps a page per size class **per thread** for the life of
the thread, so resident memory follows thread count rather than live heap. **The swap costs 13 %
of ingest throughput and buys the memory criterion** — and that 13 % is already larger than any
effect this study measured for PGO.

**So the cheap experiment is running**: A0 against A0 with the allocator as the only difference,
eight counted rounds, no toolchain work
([B-18](../backlog/B-18-allocator-probe.md)). **RQ1 should be re-measured on a paged-allocator
build before anyone concludes the macro half has no room**
([B-20](../backlog/B-20-ceiling-on-the-paged-allocator.md)). Allocator work remains a non-goal,
so the number stays outside the verdicts.

## The mechanism works, and is worth 11–13 %

RQ2 is the question the case for this study rested on, and the answer is unambiguous. The IR
carries the canonical promoted-and-inlined shape at the benchmark's own dispatch sites:

```llvm
%48 = icmp eq ptr %47, @"kfun:S1#area(kotlin.Long){}kotlin.Long"
br i1 %48, label %if.true.direct_targ.i, label %if.false.orig_indirect.i, !prof !679

if.true.direct_targ.i:
  call void @Kotlin_mm_safePointFunctionPrologue() #162
  %49 = add i64 %acc.1, 1            ; S1.area is x + 1 — the body, inlined
```

Six guarded sites in the PGO arm against **zero** in A0. Nine interleaved rounds, 99 % intervals:

| distribution | measure | A0 ns/op | A2 ns/op | change |
|---|---|---:|---:|---:|
| 90/10 | `itable` | 1.642 ± 0.080 | **1.459 ± 0.047** | **−11.2 %** |
| 90/10 | `vtable` | 1.272 ± 0.079 | **1.112 ± 0.044** | **−12.6 %** |
| 90/10 | unit control | 0.791 ± 0.031 | 0.792 ± 0.028 | +0.1 % |
| uniform ×8 | `itable` / `vtable` | — | — | +5.2 % / +3.5 %, intervals overlap |

**Both controls of known outcome hold.** Uniform rotation gains nothing, exactly as the measured
`icp-remaining-percent-threshold = 30` predicts for eight receivers at 12.5 % each.

**But the arm that carries the verdict is not the pre-registered one, and no amendment moved it.**
The brief's RQ2 describes sites with "one receiver at run time"; 90/10 was listed as a *control*.
The declared case came in at **−7.9 % and did not separate**. The substantive verdict is still
green — promotion fires, inlining is in the IR, and the effect clears the bar on both dispatch
shapes — but it clears it on the control arm, and the first version of this document reported
that without saying so.

**And 90/10 gains more than a single receiver does** (−11.2 % against −7.9 %, the latter not
separating). Not an inversion, and the reason is the most transferable thing here:

> **Hypothesis, not a finding: promotion may help most where the hardware helps least.** With one
> receiver the indirect-branch predictor is already perfect and the guard only adds a compare; at
> 90/10 it misses a tenth of the time, and the guard converts that miss into a predictable direct
> branch.

**Three reasons this is labelled a hypothesis.** The ordering it asserts rests on −11.2 % against
−7.9 %, and **the second number does not separate from zero**, so the two are not ordered. These
hosts expose no PMU, so branch misses cannot be counted and the mechanism cannot be checked
directly. And there is a competing explanation that needs no predictor at all: **inlining removes
call overhead in both cases**, whatever the branch predictor does.

## RQ0: the mechanism works, the verdict is grey

A profile comes out of a Kotlin/Native binary, merges as IR-level, and applies — on stock tools,
with no fork. That is the useful part and it is solid.

**It is not green, and the first version of this document said it was.** The brief defines green
*on the macro subject*, and this is the microbenchmark. Worse, the numbers reported — 916
functions in the profile, 929 annotated defines — **are two different sets, and neither is the
pre-registered ratio**. Green needs two numbers that were never computed:

- how many functions **with non-zero counts** had the profile applied;
- how many were **dropped on a hash mismatch**.

A4.4's re-scope moved the *item* to the microbenchmark; it did not move RQ0's green condition.
Both gaps are [B-21](../backlog/B-21-rq0-the-two-numbers.md).

## A bound on promotion's contribution, independent of the bucket arithmetic

RQ2 measured the saving directly: **0.16–0.18 ns per promoted call** (−11.2 % of 1.642 ns,
−12.6 % of 1.272 ns). That gives a bound the ceiling argument does not need:

| to move | at 0.17 ns saved per call | needs |
|---|---|---|
| 1 % of a 1 ms request | 10 000 ns | ~**60 000** promoted calls |
| 1 % of **this service's** 7.8 ms request | 78 000 ns | ~**460 000** promoted calls |

**This bounds promotion only.** Hot/cold splitting and hotness-scaled inlining thresholds are
separate PGO effects and are not covered by it.

**And one detail from the IR excerpt caps inlining generally.** The promoted, inlined body still
contains `call void @Kotlin_mm_safePointFunctionPrologue()`. Checked in the final binary:
`itable` carries four such calls in its IR and the disassembly resolves them to
`safePointAction`. **The safepoint poll survives inlining**, so every inlined callee still pays
for one — a ceiling on what inlining can return anywhere in Kotlin/Native, not just here.

## The ceiling says the mechanism has nowhere to pay off here

| endpoint | rate | Kotlin self | + runtime | kernel | libc & native |
|---|---:|---:|---:|---:|---:|
| `GET /health/live` | 960 | 32.55 % | 50.38 % | 23.31 % | 25.69 % |
| `POST /hooks/{id}` | 180 | 21.22 % | 32.33 % | 33.35 % | 31.00 % |
| `GET /api/events` | 120 | 16.40 % | 37.13 % | 14.83 % | 45.91 % |
| `GET /journal` | 48 | 13.84 % | 41.24 % | 13.86 % | 42.83 % |

Each endpoint measured at 50–70 % of its own saturation, every run shown unsaturated, zero
unresolved samples.

**The gradient runs the wrong way for this study.** The endpoint that parses nothing, touches no
database and serialises nothing has twice the Kotlin share of the one that renders a page. PGO's
territory shrinks exactly where the service does work.

**The arithmetic that follows is the study's real answer.** At a 20 % bucket, a 5–15 % return on
the code PGO touches is 1–3 % of a request. The ruler puts the macro bar at `max(5 %, 2 × ruler)`
— 9.3 % at four counted rounds, 5 % at eight. **On every endpoint that does real work the
expected effect is at or below the floor, in the best case.** The mechanism is real; the room for
it on this service is not.

## Where the CPU actually goes, which may outlast the question that was asked

The largest single consumer is **Kotlin/Native's own allocator calling libc malloc**:

| caller above the allocator | ingest | api/events | journal | health |
|---|---:|---:|---:|---:|
| `CustomAllocator::CreateObject` | 3.70 % | 3.52 % | 4.50 % | 6.50 % |
| `CustomAllocator::CreateArray` | 2.69 % | 5.93 % | 6.87 % | 4.40 % |
| `MainGCThread::PerformFullGC` | 0.71 % | 1.25 % | 1.63 % | 1.26 % |
| `sqlite3MemMalloc` | — | 2.50 % | 2.09 % | — |
| Rust (`sqlx4k`) | — | 0.58 % | 0.46 % | — |

**11.0–18.9 % of all samples have an allocator function as their leaf** — on `/journal` that
exceeds the entire Kotlin bucket. It is not Ktor's buffers and not mostly SQLite. This is what
`pagedAllocator=false` means, and that is the setting the pinned build uses, so the alternative is
a build property rather than only an `LD_PRELOAD` probe. Allocator work is a non-goal of this
brief, so this is recorded outside the verdicts.

## What the brief got wrong, and it was worth finding

**There is no fork.** The brief's fixed setup says *"the pipeline has to be changed, and a stock
distribution cannot be"*. At 2.4.20 the stock compiler exposes `-Xllvm-module-passes`, which
replaces the module optimisation pipeline string outright, plus `-Xsave-llvm-ir-after` and
`-Xcompile-from-bitcode`. And `llvm-21-x86_64-linux-dev-116` — the exact bundle
`konan.properties` names — was already installed, carrying `opt`, `llvm-profdata`,
`libclang_rt.profile.a` and `pgo-instr-gen`, `pgo-instr-use`, `instrprof`, `pgo-icall-prom`.

**The patch set is two build-level changes**, neither in the compiler: a property so Route B's
flags reach the build, and a replaced object in the profile-runtime archive.

**Arm A4 has to be replaced, not merely restated.** Its implicit model is that a profile from an
unrelated workload is largely rejected. **Two unrelated Kotlin/Native programs share 2 933 of
2 938 defines — 99.8 % of the module**, because the runtime and stdlib dominate, so an unrelated
profile is mostly a *correct* profile for everything except the handful of functions that differ.

**A control that still does the job: a flattened profile.** Export the trained profile with
`llvm-profdata merge --text`, set every counter to the same value, convert it back. Every
function then carries a profile and none of them carries information. **If that build matches A2,
the gain is not profile-guided.** [B-23](../backlog/B-23-flattened-profile-control.md).

**The offered rate is part of the gate.** A saturated endpoint reports 3.7× the Kotlin share:
`/journal` read 55.55 % saturated and 14.92 % clean. The brief fixed a rate per endpoint and never
said how to choose one.

**The gate thresholds were sized against a bar that did not exist.** 40 % and 20 % were set
against a 5 % macro bar before the ruler was measured. At the measured bar of 9.3 % with four
rounds, even a green RQ1 could not have cleared it.

## What is not measured, and why

**RQ3, RQ4, RQ5, RQ6.** Route B reaches the service's compiler — 71 MB of IR, instrumented in 9.3
seconds — and fails at its linker for two reasons invisible on a microbenchmark:

1. `undefined hidden symbol: _DYNAMIC`. The pinned arm links `-static`; the profile runtime's
   binary-id writer needs a dynamic executable. **The profile runtime and a fully static link are
   incompatible as shipped.**
2. `undefined symbol: rd_kafka_conf_new` and the rest. **`-Xcompile-from-bitcode` loses the native
   dependency graph** — `DependenciesTracker` builds it from the klib graph, and resuming from
   bitcode has no klib graph. No flag supplies it.

**The reason given for not running it was the wrong reason.** The first version of this document
said the fixes "make the measured binary less like the pinned one". What the comparison actually
requires is that **A0 and A3 be built identically apart from PGO** — resemblance to the pin is a
separate and lesser concern. Corrected, with the plan that follows from it:

- **The static link.** Link *both* arms dynamically, and run A0-static against A0-dynamic once so
  the change has a measured size rather than an assumed one.
- **The native dependencies.** The brief's own Route B says to **replay the linker command the
  normal build prints**, with the PGO object substituted — not to go through
  `-Xcompile-from-bitcode`, which is what loses them. Chasing archives by hand confirmed the
  point: supplying librdkafka's five archives only moved the failure to `sqlx4k`'s symbols, and
  there is no reason to think that is the last of them.

**Whether to run it at all depends on the allocator.** If a paged allocator lifts Kotlin plus
runtime to around 60 %, the probe is worth the work. If it does not, the ceiling and the per-call
bound above are already the answer. [B-21](../backlog/B-21-rq0-the-two-numbers.md) and
[B-22](../backlog/B-22-replay-the-linker-command.md).

**The GC log** RQ1 was to carry: `-Xruntime-logs=gc=info` is a compile-time flag the subject's
build does not expose. The collector's *share* is measured by symbol; its pause and sweep times
are not.

**The inclusive column is a lower bound.** 21.9–33.6 % of stacks have no callers, because
optimised Kotlin/Native omits frame pointers.

## Open questions

**Why does `--call-graph dwarf` return nothing on Kotlin/Native?** A control that the
frame-pointer capture profiles without trouble — 11 990 stacks, every one carrying a Kotlin frame
— returns **zero stacks** under dwarf. Three candidate mechanisms were ruled out: `.eh_frame` is
present and large (1.35 MB, 269 296 entries), this `perf` reports `dwarf-unwind: [ on ]` with
libdw, and the stack-dump size was tested from 2048 to 16384 bytes. **The cause is unknown**, and
it matters because the inclusive column depends on it.

**Why is the Route B binary 76 % larger and 3.7 % cheaper than the retired one?** GLOBAL symbols
go 840 to 10 884 while Kotlin functions, C++ and Rust barely move. The cause cannot be
established — the retired binary's source is gone.

## Claims withdrawn during the work

- *"Longer settling halves the spread."* The unpaired estimator was being fooled by a monotonic
  drift; the paired estimator barely moves with settle length.
- *"The real subject runs in a container."* Two harnesses live in xyk's `bench/`; the grep found
  the older single-host one.
- *"razves is the instrument for RQ1's buckets."* It cannot read a `perf.data`; its `profile`
  command consumes its own sampler's dump.
- *"The runtime and Rust cannot be separated by mangling on this subject."* True of razves's
  reader; this Rust emits v0 mangling, and perf demangles both.
- *"`kfun:` is one Kotlin prefix of twelve, so the bucket must be widened."* Widening cannot
  change a self-sample share: of 11 804 `FUNC` symbols, every Kotlin-prefixed one is `kfun:`.

## The instrument, and what it cost to trust it

Fifteen defects were found in this study's own harnesses, and every one of them produced evidence
indistinguishable from a real result: a check that compared a value with itself; two idle gates
that could never open; two `pkill -f` patterns matching their own command line; a driver that
exited zero after failing; a profiler pointed at the wrong pid; a capture of a binary that had
been deleted; an identity implementation that made a benchmark loop dead; a receiver index whose
cost differed between arms; repeats that were not interleaved; and a unit control that separated
by 31.5 % on a measure performing no dispatch.

**The last of those is the one to keep.** Each guard that caught something was cheap, and none of
them would have been added by someone confident the measurement was fine.
