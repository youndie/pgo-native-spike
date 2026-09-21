---
id: 2026-09-20-instrumentation-pgo
title: Instrumentation PGO for Kotlin/Native — results
type: research
status: active
date: 2026-09-20
---

# Instrumentation PGO for Kotlin/Native — results

**Final.** **RQ0 is green on the macro subject**, which is the one thing the brief asked that
this study can answer yes to. **Everything unmeasured here is unmeasured for one reason: a
profile-carrying module cannot pass Kotlin/Native's own LTO pipeline**, so no PGO binary of the
service was ever built. A2.3's drop rule exists and was declared in advance, but **it never fired
on the subject** — only on a default-allocator build that is not the subject — so it decided
nothing, and this document no longer leans on it. Every number here
has a backlog item, a log directory and a command behind it; nothing is carried over from another
project or inferred from a prior. The recipe is [`recipe/pgo.sh`](../../recipe/pgo.sh), which runs.

The pre-registration is [BRIEF.md](../../BRIEF.md), including three sets of amendments and the
reason each was made. The evidence this study started from is
[research-architecture.md](research-architecture.md).

## Verdict table

| RQ | Question | Verdict | |
|---|---|---|---|
| **RQ0** | Can a Kotlin/Native release binary write a `.profraw` that merges, and can the toolchain apply the resulting `.profdata`? | **GREEN** | **on the macro subject**: the profile merges IR-level from 4 480 real requests, and **5 762 of 5 763 functions with non-zero counts have it applied — 99.98 % against the 80 % line, 0 dropped on a hash mismatch**. On stock tools, with no fork |
| **RQ1** | What share of self CPU is Kotlin code? | **GREY** | **13.84–32.55 %** across four endpoints on the pinned build, at the rate A2.2 fixes. (An earlier 35.38 % is `/health/live` at 200 rps — a different working point, and splicing the two into one range was an error.) Also measured on the default allocator, where Kotlin's share rises and the sum with the runtime falls |
| **RQ2** | Does indirect call promotion fire on Kotlin dispatch, and what is it worth? | **GREEN**, on an arm the brief listed as a control | promotion and inlining in the IR; −11.2 % itable and −12.6 % vtable at 99 % confidence **on 90/10**. The pre-registered single-receiver case came in at −7.9 % and did not separate |
| **RQ3/RQ4** | Macro effect on the service | **NOT MEASURED** | a toolchain blocker, not a rule: a profile-carrying module cannot pass Kotlin/Native's own LTO pipeline (`CG Profile`). The ceiling and the per-call bound both predict an effect below resolution, and that is a prediction, not a measurement |
| **RQ5** | How long does a profile live? | **NOT MEASURED**, and **partly answered** | its green is *a fraction of the RQ3 effect*, so the same wall blocks it. But its structural half needed no macro arm: across a Ktor minor-version bump and four commits a profile keeps **99.683 % of its counter weight** (96.46 % of its functions — the losses concentrate in a few hot shared ones) |
| **RQ6** | What does it cost in binary size? | **NOT MEASURED** | it needs a PGO binary that went through Kotlin/Native's own LTO. The one built with external LTO is 1.8 MB against 485 KB and is not comparable to anything |
| — | The ruler | **2.92 %** per paired round | ±4.64 % at four counted rounds, ±2.44 % at eight. **Characterised on a statically linked binary**; a dynamically linked arm ran at roughly twice that and is not covered by it |

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

### The experiment has now run, and it is the largest effect in this study

| arm | µs CPU per request |
|---|---:|
| `pagedAllocator=false` — the pin | **8 175** |
| `pagedAllocator=true` — the default | **6 756** |
| paired, eight counted rounds | **+19.01 %**, 95 % CI **±2.33 %** |

**The base, because a ratio without one is ambiguous:** 19.01 % is the *paired* estimator — the
mean of the per-round differences, each as a share of its own pair. The two simple ratios of the
means bracket it: the 1 419 µs gap is **21.0 %** of the cheaper arm and **17.4 %** of the dearer.

**Nineteen percent of request CPU, from one build flag, with no compiler work** — against a macro
threshold of 5 % and a best-case PGO effect of 11–13 % measured on a microbenchmark whose
per-call bound says it is worth almost nothing at service scale.

It does not follow that the product should flip it: that setting is what survives a 64 MiB limit
10 times in 10 against paged's 1 in 10, and this run had no container limit. **The honest form is
that the memory criterion costs this service a fifth of its request CPU** — previously priced by
the subject at 13 % of ingest throughput, and now measured larger on the CPU axis.

**And the mechanism names a question nobody has asked, which may be worth more than anything
else in this document.** Resident memory under the paged allocator follows *a page per size class
per thread*, so it is a function of **thread count**, not of live heap. Whether the paged
allocator fits in 64 MiB **with fewer threads** has never been tested. If it does, the trade
dissolves and the 19 % is recoverable — a cheaper question than anything PGO posed, and the
natural RQ1 of the next study.

**And a faster *system* malloc is not the answer either — but read what was measured.**

**The pinned build is `-static`, so `LD_PRELOAD` is ignored entirely**: the service runs, answers
200, and jemalloc appears **zero times in `/proc/<pid>/maps`**. A preload probe against the
shipped binary measures nothing and would report it as "jemalloc does not help". **So the probe
was run on a *dynamically linked* build of the same commit**, not on the pin — sound because the
two builds' IR is byte-identical (B-21), so only the link differs.

On that build the preload demonstrably took effect, which is the difference between a null and a
no-op: **5 jemalloc regions in `/proc/<pid>/maps`**, and in a profile **68 samples in
`libjemalloc.so.2`** with `calloc`, `free`, `malloc` and `posix_memalign` served by it and **no
malloc-family symbol left in libc**.

The result, eight paired rounds, both arms the same dynamic binary and the preload the only
difference: **+0.65 %, 95 % CI ±6.08 %** — below resolution.

**The interval is the finding's own caveat, and it is about the ruler.** Per-round sd was
**7.27 % against the ruler's 2.92 %** — two and a half times — so eight pairs bought ±6.08 %
instead of ±2.44 %. The 5 % bar this study operates under rests on that 2.92 %, and **it did not
reproduce here**.

**Three candidates, and two of them are weakened by runs already taken:**

- *The stand drifts.* Weakened. **The allocator probe on the same stand reproduced the ruler
  exactly** — ±2.33 % at eight rounds against the predicted ±2.44 %. Whatever inflated this run
  is not a permanent property of the stand.
- *jemalloc's own arm is noisy*, its decay purging calling `madvise` on a timer rather than with
  the load. Weakened. **Per-arm sd is 5.84 % without the preload and 6.38 % with** — both arms
  are noisy, so the preload is at most a small part of it.
- *The dynamic binary is noisier, and the ruler never measured one.* **This is the candidate the
  data point at.** The allocator probe used `xyk-pagedoff` and `xyk-paged`, both `-static`; this
  one used a dynamically linked binary, and the ruler's 2.92 % was characterised on a static one.

**The mechanism offered for it — ASLR moving a PIE's load address every run, so alignment and
aliasing change between rounds — was tested, and the test could not resolve it.** The same
dynamic binary, both arms, eight counted rounds under `setarch -R`:

| | paired sd | 95 % CI for that sd |
|---|---:|---|
| ASLR on | 7.27 % | [4.81, 14.80] |
| ASLR off | **5.93 %** | [3.92, 12.07] |
| the ruler, static binary | 2.92 % | — |

**Those intervals overlap almost entirely.** An sd estimated from eight pairs is a wide thing,
and a 1.2× difference between two such estimates is not a result — this study's own rule about
one run per variant applies to spreads as much as to means. What can be said: every per-arm
figure moved down together (5.84 % and 6.38 % on, against 3.92 % and 4.10 % off), which is the
direction the mechanism predicts, and **even with ASLR disabled the dynamic binary sits at
3.9–4.1 % against the static ruler's 2.92 %**. So ASLR is not shown to be the cause and is not
sufficient as a fix.

**What that leaves for the recipe** is the conservative reading rather than the explanation: a
measured arm on a dynamically linked binary should not assume the ruler, and needs either its
own characterisation or more rounds.

Enough to exclude anything near the build flag's 19 %; not enough to separate 5 % from nothing.

**The original wording**: A0 against A0 with the allocator as the only difference,
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

**And the rival explanation — that a PGO build is simply a *different* build, and any rebuild
would move the number — is excluded, in this order of strength.**

1. **The IR carries the mechanism at the benchmark's own sites**: a guard against the dominant
   target and the callee's body inlined behind it, six such sites against zero in A0. A rebuild
   does not produce that shape; a profile does.
2. **The unit control moves by +0.1 %** — the same arithmetic with no dispatch at all. A layout
   or codegen effect large enough to explain −11 % would have to leave that untouched.
3. Supporting only: uniform and 90/10 come from the same pair of binaries, so a whole-binary
   effect would move both. This is weaker than it first looks — **layout effects are local**, a
   loop's alignment can change in one measurement and not another — which is why it is third
   rather than first.

**But the arm that carries the verdict is not the pre-registered one, and no amendment moved it.**
The brief's RQ2 describes sites with "one receiver at run time"; 90/10 was listed as a *control*.
The declared case came in at **−7.9 % and did not separate**. The substantive verdict is still
green — promotion fires, inlining is in the IR, and the effect clears the bar on both dispatch
shapes — but it clears it on the control arm, and the first version of this document reported
that without saying so.

**And 90/10 gains more than a single receiver does** (−11.2 % against −7.9 %, the latter not
separating). Not an inversion, and what follows is a hypothesis rather than a finding:

> **Hypothesis, not a finding: promotion may help most where the hardware helps least.** With one
> receiver the indirect-branch predictor is already perfect and the guard only adds a compare; at
> 90/10 it misses a tenth of the time, and the guard converts that miss into a predictable direct
> branch.

**Three reasons this is labelled a hypothesis.** The ordering it asserts rests on −11.2 % against
−7.9 %, and **the second number does not separate from zero**, so the two are not ordered. These
hosts expose no PMU, so branch misses cannot be counted and the mechanism cannot be checked
directly. And there is a competing explanation that needs no predictor at all: **inlining removes
call overhead in both cases**, whatever the branch predictor does.

## RQ0 is green, on the subject the brief named

A profile comes out of a Kotlin/Native binary, merges as IR-level, and applies — on stock tools,
with no fork. **On the service, not only on the microbenchmark.**

The pre-registered condition, unedited: *"On the macro subject: the profile merges, and at least
80 % of functions with non-zero counts have it applied in the rebuilt IR."* Measured
([B-21](../backlog/B-21-rq0-the-two-numbers.md), `logs/b-21/`), from **4 480 real requests across
all four endpoints** of the instrumented service:

| | |
|---|---:|
| functions in the profile | 13 285 |
| **... with a non-zero counter** | **5 763** |
| **... of those, profile applied** | **5 762** |
| **... dropped on a CFG hash mismatch** | **0** |
| **share applied, against the 80 % line** | **99.98 %** |

**And the zero is believable, because the counter was shown able to report the opposite.** With
every CFG hash flipped by one bit and names and counters untouched, `opt` emits **13 784**
hash-mismatch warnings against the true profile's **0**, the module keeps **140** `!prof`
annotations against **24 387**, and the applied count goes to zero. Both instruments move
together, in both directions.

**The binary this rests on is the first real use of the replayed link.** It is also where the
static pin had to be stepped around: the profile runtime needs a dynamic executable, and merely
dropping `-static` leaves `-Bstatic … -lc`, which the loader rejects outright. The training arm
uses the link line of a non-static build — sound because **the two builds' IR is byte-identical**,
checked rather than assumed, so `staticLink` cannot reach what the profile is about.

**What green does not claim.** The condition says *in the rebuilt IR*, and that is what was
measured. A rebuilt *binary* carrying the profile is blocked by the `CG Profile` wall described below, and
RQ0's green does not ask for one.

**The earlier grey, for the record.** The first version of this document called RQ0 green on the
microbenchmark; the brief defines green on the macro subject. Worse, the numbers reported — 916
functions in the profile, 929 annotated defines — **are two different sets, and neither is the
pre-registered ratio**. Green needs two numbers that were never computed:

- how many functions **with non-zero counts** had the profile applied;
- how many were **dropped on a hash mismatch**.

A4.4's re-scope moved the *item* to the microbenchmark; it did not move RQ0's green condition.
Both numbers now exist on both subjects.

**Both numbers have since been computed on the microbenchmark** ([B-13](../backlog/B-13-publish-the-result.md),
`logs/b-13/`), by a reader with its own control:

| | |
|---|---:|
| functions in the profile | 934 |
| ... with a non-zero counter | 171 |
| **... of those, profile applied** | **170** |
| **... dropped on a hash mismatch** | **0** |

So on the microbenchmark the profile applies essentially completely. The macro subject was
measured later, through B-22's replayed link, and gives the 99.98 % in the verdict table —
**that is what made RQ0 green.** The grey described here is the state this document reported
before that run, kept because a retraction is appended rather than edited away.

**And the recipe is a script that a reader can run**: [`recipe/pgo.sh`](../../recipe/pgo.sh),
exercised end to end on a host that had built nothing in this study. **Its two load-bearing
steps were verified by removing them**, rather than by having worked once — without
`-u__llvm_profile_runtime` the binary links, runs and silently writes no profile at all; with
the stock version object the profile merges as `Front-end` and `pgo-instr-use` refuses it.

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

### And the build property does not rescue it — it makes it worse

The ceiling above sits on `pagedAllocator=false`, so the obvious objection is that the default
build might leave PGO more room. It was measured, at rates re-derived from the knees the paged
build actually reaches:

| endpoint | rate | samples | Kotlin self | runtime | **self + runtime** | kernel | libc & native |
|---|---:|---:|---:|---:|---:|---:|---:|
| `GET /health/live` | 2 400 | 83 127 | 42.29 % | 5.15 % | 47.43 % | 35.55 % | 16.28 % |
| `POST /hooks/{id}` | 240 | 53 191 | 25.87 % | 2.58 % | **28.46 %** | 40.59 % | 27.33 % |
| `GET /api/events` | 180 | 52 757 | 23.87 % | 4.49 % | **28.37 %** | 19.83 % | 49.37 % |
| `GET /journal` | 144 | 45 536 | 21.95 % | 6.62 % | **28.57 %** | 21.09 % | 48.01 % |

Unresolved is **0.00 %** on every row. **The rates are not the pinned build's** — they are
re-derived from the knees the paged build reaches, which are higher — so the two tables are not
a like-for-like comparison of shares. That matters, because this study's own data show shares
move with rate: `/health/live` reads 32.55 % Kotlin at 960 rps and 35.38 % at 200.

**Three sums landing within 0.21 points of each other deserves suspicion, so here is why it is
not an artefact**: the rows come from different captures with different sample counts, and the
components differ widely — Kotlin self spans 21.95–25.87 % and runtime 2.58–6.62 %. One file read
three times would show identical components, not identical sums. It is a coincidence, and it is
reported as one rather than as a pattern.

**kernel plus libc reads higher on the paged build — 67.9–69.2 % against 56.7–64.4 % — and that
is renormalisation, not a puzzle.** The allocator removes CPU, the denominator shrinks, and every
untouched bucket's *share* rises by 1/(1−r). The multipliers say so directly: on `/hooks` Kotlin
goes ×1.219 and kernel ×1.217 — **the same factor, for two buckets with nothing in common** —
which puts r at 17.9 %, and the removed points reconcile as 9.0 from runtime plus 8.6 from libc's
malloc, 17.6 in total. An earlier version of this document called the rise unaccounted for; it is
accounted for, and the reviewer who did the arithmetic was right.

**Converting the shares to absolute µs turns that into the strongest check in this study of
whether the attribution grammar is telling the truth.** `/hooks` is the one endpoint with µs CPU
per request on both builds:

| bucket | pinned µs | paged µs | change |
|---|---:|---:|---:|
| **Kotlin self** | 1 735 | 1 748 | **+0.8 %** |
| **kernel** | 2 726 | 2 742 | **+0.6 %** |
| runtime | 908 | 174 | −80.8 % |
| libc & native | 2 534 | 1 846 | −27.1 % |

**The two buckets that cannot change are consistent with not changing.** Same source, same
compiler, same syscalls: Kotlin self and kernel come out at +0.8 % and +0.6 %. Those figures are
a share multiplied by a CPU-per-request that itself carries ±2.33 %, so **the honest reading is
"consistent with zero", not "moved by under a point"** — the ruler does not support the second.
What the check establishes is that a correct attribution must put these two at zero and a broken
one need not, and both land there. And the two buckets the allocator touches account for **1 393 µs of
the measured 1 419 µs gap** — a 26 µs residual, 1.8 %, which is the small buckets the table omits.

A share table cannot show this and an absolute one does, which is an argument for reporting µs
per bucket rather than percentages wherever both builds have a request cost. `/api/events` is
also where the multipliers *disagree* — Kotlin ×1.455 against kernel ×1.337 — and that is the
rate difference showing up, as it should.

Kotlin's own share **rises** on every endpoint — `/journal` nearly doubles — but the runtime
bucket collapses further than Kotlin grows, so **their sum, which is the most a PGO arm could
touch, falls to a uniform ~28.5 %** on all three work endpoints. The cheaper allocator removes
work that was PGO's territory rather than moving work into it.

**This is what fires A2.3**, the drop rule the owner wrote before the run that decided it: *if
Kotlin self plus runtime stays under 40 % on every work endpoint, Route A, RQ5 and RQ6 are
dropped.*

**And it fires on one build only, which is worth stating precisely rather than rounding off.** On
the **pinned** build — the subject — the rule **does not fire**: `/journal` is 41.24 %, over the
40 % line by 1.24 points. It fires on the **default-allocator** build, which is not the subject
and was measured after the first outcome was known. An earlier version of this document said the
conclusion "does not depend on which allocator the reader prefers"; by the letter of the rule
that is false, and the reviewer was right to catch it.

**What does hold for both builds is the substantive argument rather than the rule**: the ceiling
says the bucket PGO can touch is 28–41 % depending on build and endpoint, and the per-call bound
below says promotion needs ~460 000 promoted calls per request to move 1 % of this service's
request. Those two survive either allocator. The *rule* does not.

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

## What was not measured, what blocked it, and what is moot

**RQ3, RQ4, RQ5 and RQ6 are all not measured, and all for the same reason: no PGO binary of the
service could be built.** An earlier version of this section said they were *dropped by A2.3* on
the bucket measurement, and that was wrong twice over — A2.3 names only Route A, RQ5 and RQ6, and
it does not fire on the subject at all (`/journal` is 41.24 % against its 40 % line). **So the
study is reporting questions it could not open, and says so** rather than presenting a blocker as
a decision.

**What the ceiling and the per-call bound still give is a prediction, not a verdict**: at a
28–41 % bucket and 0.16–0.18 ns per promoted call, the expected macro effect is below this
stand's resolution. That is worth stating and is not worth confusing with a measurement.

The obstacles below are recorded because **any future arm on this subject meets them first**. Route B
reaches the service's compiler — 71 MB of IR, instrumented in 9.3 seconds — and fails at its
linker for two reasons invisible on a microbenchmark:

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

**Both have since been done, and the second one ended somewhere better than expected**
([B-22](../backlog/B-22-replay-the-linker-command.md), `recipe/replay-link.sh`, `logs/b-22/`).

`-Xverbose-phases=Linker` prints the whole `ld.lld` invocation and `-Xtemporary-files-dir` keeps
the object it names. **Replaying that line with the compiler's own object reproduces the ordinary
build byte for byte** — so the dependency list is the build's, no archive is ever chased, and the
static-link question dissolves: only the *training* binary links the profile runtime, and no
measured arm's linkage changes at all.

**The training arm then works end to end.** Instrumented bitcode carries no profile metadata, so
kotlinc runs its own full pipeline and emits the object *even though its own link step fails*;
the replayed line plus the profile runtime gives a binary that runs and writes an IR-level
profile.

**The use arm does not, and the reason is a property of the toolchain rather than of this
service.** A module carrying profile metadata makes kotlinc emit the `CG Profile` module flag
**twice** — once from its LTO pipeline, once from the `clang++` codegen step — and it then
rejects its own module:

```
module flag identifiers must be unique (or of 'require' type)
!"CG Profile"
```

Neither copy comes from the input; `opt -passes=pgo-instr-use` emits no such flag. The only
`-Xllvm-lto-passes` value that avoids the collision is one that does **no LTO**, and once LTO is
external the arm stops being comparable: Kotlin/Native's own LTO internalises and dead-strips
**3 027 defines to 411**, which `opt -passes=default<O3>` does not reproduce because nothing has
told it what may be internalised. Built that way, both arms run and their link lines differ only
in the object — and the binary is **1 824 320 bytes against the ordinary build's 484 608**.

**This replaces "the linker failed" with something a reader can act on.** The first form invited
more linker work. The real obstacle is that **a profile-carrying module cannot pass through
Kotlin/Native's own LTO pipeline on 2.4.20**, which is where anyone attempting instrumentation
PGO on a Kotlin/Native service will stop — and it is the one thing in this study that a fork
would plausibly have fixed.

**That condition has since been tested and it failed.** The paragraph this replaces said the
probe was worth the work *if* a paged allocator lifted Kotlin plus runtime to around 60 %. It
lifts Kotlin's own share and lowers the sum, to ~28.5 %. The macro arms are dropped.

**What became of each, now that the backlog is closed.**

| item | outcome |
|---|---|
| B-22 — replay the linker command | **done.** The replay reproduces the ordinary build **byte for byte**, on the service as well as on a toy. It is what made the training binary, and RQ0's green, possible |
| B-21 — RQ0's two numbers | **done**, on the macro subject: 5 762 of 5 763, 0 hash mismatches |
| B-19 — commit in the binary | **done**; the upstream half is open for review as youndie/xyk#8 |
| B-23 — flattened profile | **dropped as moot**: it replaced arm A4, which is macro, and the question A4 asked is answered on the micro half |
| B-15 — a second sampler | **done on the microbenchmark, impossible on the service**: an in-process signal sampler kills Ktor CIO through an unretried `EINTR` in `pselect` |
| B-18 — the allocator probe | **done**, and outside the verdicts |

**What is still not measured is RQ3/RQ4**, and the obstacle is the `CG Profile` wall rather than
a rule or a budget.

**The GC log** RQ1 was to carry: `-Xruntime-logs=gc=info` is a compile-time flag the subject's
build does not expose. The collector's *share* is measured by symbol; its pause and sweep times
are not.

**The inclusive column is a lower bound.** 21.9–33.6 % of stacks have no callers, because
optimised Kotlin/Native omits frame pointers.

## RQ1 has one sampler and one grammar, and a second could not be had

Both were written here, which is a weakness the study named from the start and tried to remove:
razves offers an independent sampler, an independent symbol reader, and its own `BY ORIGIN` table
drawing RQ1's boundary by somebody else's hand ([B-15](../backlog/B-15-second-sampler-for-the-ceiling.md),
`logs/b-15/`).

**It cannot run against this subject.** razves samples in a signal handler; the signal interrupts
Ktor's CIO selector in `pselect`; and **Ktor's native selector does not retry on `EINTR`** — it
converts errno to an exception, uncaught, and the process dies. Same binary, same load, the
sampler the only difference: **off survives, 997 Hz dies, and 97 Hz died in two of three
60-second runs**.

**The defect is not razves's.** A `pselect` caller that ignores `EINTR` is broken for any process
that receives a signal at all; razves only makes it frequent enough to see. The general form is
worth more than this study's cross-check: **no in-process signal-based profiler can run against
Ktor CIO on Kotlin/Native** until that loop retries — and it is why `perf`, which samples from
outside and delivers no signals, remains the only instrument that can answer RQ1 here.

**And the obvious fix is already applied and cannot work.** razves installs its handler with
`SA_RESTART`, which is what anyone would reach for; `signal(7)` lists `epoll_wait`, `epoll_pwait`,
`poll`, `ppoll`, `select` and `pselect` as **never restarted regardless of that flag**. So no
setting on the profiler's side avoids this, and the limitation is written up where the next
person meets it: [youndie/razves#7](https://github.com/youndie/razves/issues/7).

Everything short of the run works: the sampler resolves, links, and profiles an arithmetic
control at `kotlin 100 %`, and the subject rebuilt with it costs **22 160 bytes** more than the
pin.

**So the cross-check was run where it can be — on the microbenchmark**, both samplers on one run,
and it confirms the grammar. Kotlin self: perf 87.71 %, razves 93.2 %; the gap is the kernel,
which an in-process sampler cannot see. Removing perf's 155 kernel samples puts Kotlin self
between **92.15 %** and **93.33 %** depending on where its 36 unresolved samples belong, and
**razves's 93.26 % lands inside that band, 0.07 points from the edge**, with 0 dropped samples
and 99.7 % of leaves named.

**The one disagreement is a definition, and naming it is what a second implementation buys.** The
disputed bucket is a single symbol — `Kotlin_String_equals`, 162 of 166 samples. razves decides
"runtime" from C++ Itanium mangling, so the runtime's **C entry points** fall to `c`;
`attribution.py` counts them as runtime. Neither is wrong, the boundary is a choice rather than a
fact, and the arithmetic closes exactly: razves's `c` 202 = perf's libc 38 + 162 + 2 C++ leaves.

**No published number changes.** RQ1's own buckets are still read by one sampler on the service,
because razves cannot run there at all; what is now independently checked is the **grammar** they
are read with, which is the part both subjects share.

## RQ5's structural half, which needed no macro arm

RQ5's green is *"at least two thirds of the RQ3 effect retained"*, so the wall blocks it. But the
worry underneath it — that generated names for lambdas and anonymous classes drift between
builds, and a profile goes stale on contact with a commit — is answerable with the reader from
RQ0 and no new instrument at all (**B-24**, `logs/b-24/`).

A profile trained on `6359a88`, applied to the IR of earlier revisions. **Each row is the
distance from the trained revision, not from its neighbour** — `c62412d` differs by four commits,
not by one. 5 763 functions carry non-zero counts and 1 457 158 189 counters between them:

| revision | Ktor | distance | retained, **functions** | retained, **weight** | hash mismatch |
|---|---|---|---:|---:|---:|
| `6359a88` | 3.6.0 | self | 99.983 % | **100.000 %** | 0 |
| `c4ba99f` | 3.6.0 | 1 commit, build only | 99.965 % | **100.000 %** | 0 |
| `5c701e4` | 3.6.0 | 2 commits | 99.896 % | **99.999 %** | 3 |
| `f0e5980` | 3.6.0 | 3 commits | 99.584 % | **99.968 %** | 8 |
| **`c62412d`** | **3.5.2** | **4 commits, across the version boundary** | **96.460 %** | **99.683 %** | **78** |

**The last row was missing, and without it this section claimed something it had not measured.**
An earlier version labelled `f0e5980` as "Ktor 3.5.2 → 3.6.0". It is the commit that *introduced*
3.6.0, so it and every revision after it carry the same version — **the bump was on neither side
of that comparison**. `c62412d` is the one before it, and is the only row here that crosses a
framework version.

**Crossing it costs an order of magnitude more**: 3.54 % of functions and **0.317 %** of counter
weight, against 0.42 % and 0.032 % for three ordinary commits. Hash mismatches go 8 → 78 and
`opt`'s own warnings 15 → 170.

**The conclusion survives the correction, with a bigger number.** 99.683 % of a profile's
information still lands across a web-framework minor version and four commits. Profile staleness
is not what limits how long a profile lives here — but the honest figure is ten times the one
first reported, and it is attached to the right comparison now.

**Counting functions understates retention, which is why the weighted column leads.** A lost cold
lambda and a lost hot function are not the same loss; weighting separates them.

**Generated names do change, and an earlier version of this document said they do not.** Of the
16 functions absent by name at `f0e5980`, **11 carry a generated-name marker** — all
`ingestModule$2…` lambdas, in the module whose code changed. That is name instability under a
code change, not gratuitous drift, and their combined weight is **19 counters of 1.46 billion**.

## What actually moves a hot function's hash, and it is not its source

`kotlinx.cinterop.DeferScope#executeAllDeferred` is **442 333 of the 468 374 counters lost at
`f0e5980`** — one stdlib function, most of the damage. Its source did not change and neither did
the Kotlin version. The IR says why:

```llvm
; 6359a88 — two arms
%8 = icmp eq ptr %7, @"kclass:io.ktor.network.util.getAddressInfo$$inlined$memScoped$1#internal"
br i1 %8, label %when_case1, label %when_next2
  call void @"kfun:io.ktor.network.util.getAddressInfo$$inlined$memScoped$1.invoke#internal"
  call void @"kfun:kotlinx.cinterop.refTo$$inlined$usingPinned$1...invoke#internal"

; f0e5980 — one arm, so no kclass comparison at all
  call void @"kfun:io.ktor.network.util.getAddressInfo$$inlined$memScoped$1.invoke#internal"
```

**Kotlin/Native's closed-world devirtualisation expands `invoke` on the deferred lambdas into a
chain of `kclass` comparisons, and the number of arms tracks the set of defer-lambdas reachable
in the whole program.** Add or remove one anywhere — in this case through ordinary feature
commits, with **no dependency change at all** — and a shared stdlib function's control flow, and
therefore its PGO hash, moves.

**This is a platform property with no C or C++ equivalent, and it is the mechanism behind
"CFG change in hot shared code".** A function's profile hash on Kotlin/Native is not a function
of its own source; it is a function of the whole program's composition. Anyone planning profile
reuse across builds should expect staleness to be triggered by changes that touch nothing they
wrote — which is also why the loss concentrates in a handful of hot shared functions rather than
spreading thinly.

The control holds: a build-only commit retains 100.000 % by weight, so none of this is harness
noise. `opt`'s warnings track the reader independently at 0, 0, 8, 15, 170.

**Direction.** The brief asks for the *next* three commits; the trained revision is the branch
tip, so earlier ones are used. Name and hash agreement is symmetric between two revisions, but a
forward test would additionally see names that only new code introduces, and this does not.

**It is not RQ5.** Retained *coverage* is not retained *effect*: a profile can still apply to
99.58 % of functions and be worth less, because the counts inside it describe a workload and a
code shape that have moved. That half needs RQ3.

## Open questions

**Why does `--call-graph dwarf` return nothing on Kotlin/Native?** A control that the
frame-pointer capture profiles without trouble — 11 990 stacks, every one carrying a Kotlin frame
— returns **zero stacks** under dwarf. Three candidate mechanisms were ruled out: `.eh_frame` is
present and large (1.35 MB, 269 296 entries), this `perf` reports `dwarf-unwind: [ on ]` with
libdw, and the stack-dump size was tested from 2048 to 16384 bytes. **A fourth candidate has since been ruled out**: the unwinder's lookup table is present and
well-formed — `.eh_frame_hdr` is 206 412 bytes, `.eh_frame` 1 353 176, and the `PT_GNU_EH_FRAME`
segment that tells the unwinder where to find them exists. **The cause is unknown**, and it
matters because the inclusive column depends on it.

**Is the doubled `CG Profile` flag avoidable by replaying codegen, the way the link was?** An
untested lead: `clang` may add the `CGProfile` pass only with the integrated assembler, in which
case the bitcode-to-object step could be reproduced externally — through `llc`, or by pushing a
clang flag in via `-Xoverride-konan-properties` — exactly as the link command was replayed. Both
arms would have to take the identical path for the comparison to mean anything. This is the one
lead that could still open RQ3/RQ4.

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
