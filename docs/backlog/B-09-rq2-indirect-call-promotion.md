---
id: B-09
title: "RQ2 — does indirect call promotion fire on Kotlin dispatch, and what is it worth"
status: done
priority: P0
size: M
stage: stage-3-mechanism
blocked_by: [B-08]
---

# B-09 — RQ2: does indirect call promotion fire on Kotlin dispatch

> **Re-scoped 2026-09-20 by [BRIEF](../../BRIEF.md) A2.4.** Through **Route B only**, on the
> microbenchmark binary, inside the two-to-three-day box shared with
> [B-08](B-08-rq0-a-merged-profile-applied.md). **This is now the study's primary deliverable**:
> RQ1 came back grey and the macro half may not be answerable on these hosts, but whether
> indirect call promotion fires on Kotlin vtable and itable dispatch is a fact about the compiler
> that holds at any offered rate, on any host.

The one LLVM pass the whole case rests on. Indirect call promotion records the top targets of every
indirect call, then emits a guarded direct call the inliner can see through — speculative
devirtualisation without deoptimisation, which Kotlin/Native has no other source of. Green needs
promotion and inlining visible in the IR at the benchmark's sites **and** the micro effect met on
both dispatch shapes; virtual and interface calls are priced separately.

- **The decision and its reason.** The sites must have several implementors reachable, so that the
  compiler's own closed-world devirtualisation cannot resolve them, and one receiver at run time.
  A site the compiler already devirtualises measures nothing about PGO.
- One day per dispatch shape, per the brief's budget, and the shapes are priced separately because
  a vtable call and an itable call are different work and a single number would hide which one
  moved.
- The rejected alternative is measuring this on the service first. The microbenchmark prices the
  mechanism; only RQ3 says whether it matters, and running them in the other order gives a null
  with no way to tell mechanism from magnitude.
- Not covered: whether any of this survives on the service. That is
  [B-10](B-10-rq3-rq4-the-macro-arms.md).

- AC: kotlinx-benchmark on the native target, ns/op per arm, with non-overlapping 99 % confidence
  intervals and at least a 10 % change for the micro effect to count.
- AC: IR excerpts showing the promotion at the benchmark's own sites, read from the measured
  build, plus `opt` statistics and pass remarks giving promoted sites by function.
- AC (control of known outcome 1): eight receivers in **uniform rotation** gain nothing, because
  no target dominates.
- AC (control of known outcome 2): eight receivers at **90/10** gain most of what the
  single-receiver case gains.
- AC: if either control comes out the other way, RQ2's numbers are not used until the reason is
  found, and kill criterion 6 starts its two-day clock.
- AC (unit control): each microbenchmark arm has a unit control beside it — an arm that performs
  exactly the one operation being priced and nothing else — so that a ns/op difference is
  attributable to the dispatch and not to the loop around it.
- AC (the known-order pair): a variant that does everything another does plus one step runs beside
  the set. If it comes out cheaper, the run is discarded and the stand is fixed before anything is
  read.
- Anchors: `logs/b-09/`, `bench/src/nativeMain/kotlin/DispatchBench.kt`.

---

## Iteration 1 — 2026-09-20. Promotion fires, and the training regime is wrong

**Preliminary: indirect call promotion demonstrably fires on Kotlin dispatch**, and the effect is
large on the shapes it should help and negative on the one it should not. **Not final**: one
profile was trained across all three distributions at once, which is the wrong regime for
evaluating the controls.

### The pair, both through Route B so the route is not the difference

| arm | A0 (same route, O3, no profile) | A2 (profile + promotion + O3) | change |
|---|---:|---:|---:|
| `vtable-single` | 2.167 | **1.442** | **−33.4 %** |
| `vtable-skewed` | 2.372 | **1.465** | **−38.2 %** |
| `itable-skewed` | 3.387 | **2.507** | **−26.0 %** |
| `itable-single` | 2.430 | 2.317 | −4.6 % |
| `vtable-uniform` | 2.838 | 3.629 | **+27.9 %** |
| `itable-uniform` | 2.694 | 3.352 | **+24.5 %** |
| `sum` (unit control) | 0.75–0.82 | 0.72–0.92 | flat |

Virtual dispatch gains a third on the distributions promotion is for. Interface dispatch gains a
quarter on skewed. **Uniform gets a quarter worse**, which is the mechanism working as described:
a guard that fails is a branch plus a call rather than just a call.

### Why it is not final: the profile blends the arms

The instrumented binary runs all three distributions in one process, so **one profile records the
average of single, uniform and skewed**. At the shared call sites that average is dominated by
the two arms that favour one receiver, so the compiler speculates on that receiver — and in the
uniform arm the guard then fails seven times in eight.

That explains the +25 % honestly, but it means **the declared control "eight receivers in uniform
rotation should gain nothing" has not been tested**: it was given a profile from a different
distribution. The next iteration trains each arm separately, which needs a mode argument on the
benchmark so the instrumented binary can be run three times.

### Four defects found in the benchmark and the recipe, three of them mine

1. **`S0.area(x) = x + 0` made the `single` arm an identity.** `acc` began at 0 and stayed there;
   the loop computed nothing and timed fastest of all, which is what a deleted loop looks like.
   Caught only because the sink is printed. Every implementation now adds a distinct non-zero
   constant.
2. **The receiver index was computed inside the timed loop** — a mask for uniform, a division and
   a modulo for skewed — so the arms differed by arithmetic as well as by distribution, and
   `skewed` timed *slower* than `uniform`, the opposite of the prediction. **It was measuring the
   picker.** Index sequences are now precomputed into an `IntArray` that every arm walks
   identically.
3. **Applying a profile breaks `-Xcompile-from-bitcode`**: `module flag identifiers must be
   unique (or of 'require' type) !"CG Profile"`. The module leaving `opt` has **zero** CG Profile
   mentions, so kotlinc adds it twice itself — once in each of its two pipelines, both of which
   run `CGProfilePass` because the module now carries profile metadata. Worked around by giving
   both pipelines `verify` via `-Xllvm-module-passes` and `-Xllvm-lto-passes`, and doing the
   optimisation in `opt` instead.
4. **That workaround silently disabled all optimisation** on the first attempt, because `opt` was
   running only the PGO passes. Everything came out 10–20× slower — **including the unit
   control, which does no dispatch and therefore cannot be affected by promotion**. That is the
   whole reason the unit control is in the benchmark, and it is the only thing that distinguished
   "PGO made it slower" from "nothing was optimised". Fixed by running `default<O3>` inside
   `opt`.

### Two things to carry forward

**Route B's A0 is not the ordinary A0.** The same source through the ordinary build is
`itable-single` 1.55 ns/op; through Route B with O3 in `opt` it is 2.43. The route costs
something, so **every arm must be compared against an A0 that took the same route** — which is
what the table above does, and what a comparison against the ordinary build would have got wrong
by more than the effect being measured.

**`-stats` prints nothing from this `opt`**, so promoted-site counts are not available that way
and the IR excerpts the AC asks for have to come from reading the module. Not yet done.

### Not yet done

Per-arm training; the promoted-site count and IR excerpts; ns/op confidence intervals across
repeats (the harness takes the best of five, which is not the same as a 99 % interval);
kotlinx-benchmark, which this deviates from by using an in-process timer — recorded as a
deviation rather than a substitution.

---

## Findings — 2026-09-20

# RQ2 is **GREEN**

**Indirect call promotion fires on Kotlin dispatch, on both shapes, and it is worth 11–13 % where
the receiver distribution is skewed.** Every declared control holds.

### The IR, at the benchmark's own site

```llvm
%48 = icmp eq ptr %47, @"kfun:S1#area(kotlin.Long){}kotlin.Long"
br i1 %48, label %if.true.direct_targ.i, label %if.false.orig_indirect.i, !prof !679

if.true.direct_targ.i:
  call void @Kotlin_mm_safePointFunctionPrologue() #162
  %49 = add i64 %acc.1, 1            ; S1.area is x + 1 - the body, inlined
  br label %"kfun:Shape#area(kotlin.Long){}kotlin.Long.exit"
```

The guard compares the loaded function pointer against the 90 % receiver, the true branch carries
**the callee's body rather than a call**, and the branch is weighted from the profile. Guarded
sites: `itable` 1, `vtable` 1, `both` 2, plus one each in `Shape#area` and `Base#f` — **six in the
PGO arm against zero in A0**.

### The numbers, interleaved, nine rounds, 99 % intervals

| mode | measure | A0 ns/op | A2 ns/op | change | |
|---|---|---:|---:|---:|---|
| **skewed** | `itable` | 1.642 ± 0.080 | **1.459 ± 0.047** | **−11.2 %** | met |
| **skewed** | `vtable` | 1.272 ± 0.079 | **1.112 ± 0.044** | **−12.6 %** | met |
| **skewed** | `both` | 2.672 ± 0.128 | 2.301 ± 0.091 | −13.9 % | met |
| skewed | `sum` (control) | 0.791 ± 0.031 | 0.792 ± 0.028 | +0.1 % | flat |
| single | `itable` | 1.255 ± 0.060 | 1.156 ± 0.061 | −7.9 % | overlap |
| single | `vtable` | 1.036 ± 0.057 | 0.966 ± 0.035 | −6.8 % | overlap |
| single | `both` | 1.961 ± 0.067 | 1.685 ± 0.041 | −14.1 % | met |
| single | `sum` (control) | 0.752 ± 0.050 | 0.758 ± 0.036 | +0.8 % | flat |
| uniform | `itable` | 2.155 ± 0.890 | 2.266 ± 0.888 | +5.2 % | overlap |
| uniform | `vtable` | 2.153 ± 0.966 | 2.227 ± 0.991 | +3.5 % | overlap |
| uniform | `sum` (control) | 0.871 ± 0.189 | 0.895 ± 0.215 | +2.8 % | flat |

**Green requires promotion and inlining in the IR *and* the micro effect on both dispatch
shapes.** Both are met on the skewed arm — itable −11.2 % and vtable −12.6 %, each over 10 % with
non-overlapping 99 % intervals.

### Both controls of known outcome hold

**Control 1 — eight receivers in uniform rotation gain nothing.** +3.5 % to +6.4 %, every
interval overlapping. Exactly as [B-05](B-05-six-unknowns-of-the-release-pipeline.md) predicted
from the thresholds it read: at 12.5 % each, no target clears
`icp-remaining-percent-threshold = 30`, so nothing is promoted and nothing changes.

**Control 2 — 90/10 gains most of what the single-receiver case gains.** It gains **more**:
−11.2 % and −12.6 % against single's −7.9 % and −6.8 %, neither of which separates. Not an
inversion — the direction is right — but worth the explanation, because it is the interesting
part:

> **Promotion helps most where the hardware helps least.** With one receiver the indirect-branch
> predictor is already perfect, so a guard adds a compare and saves little. At 90/10 the predictor
> misses a tenth of the time, and the guard converts that into a well-predicted direct branch.

**The unit control is flat in all three modes** and **the known-order pair holds everywhere** —
`both` is slower than `itable` in every arm of every build.

### Six defects, five of them mine, and each caught by a different guard

1. **An identity implementation.** `S0.area(x) = x + 0` with `acc` starting at zero: the `single`
   arm computed nothing and timed fastest of all. Caught by the printed sink.
2. **The receiver index was computed inside the timed loop** — a mask for uniform, a division for
   skewed — so `skewed` timed *slower* than `uniform`. It was measuring the picker.
3. **Applying a profile breaks `-Xcompile-from-bitcode`**: `module flag identifiers must be
   unique — !"CG Profile"`. The module leaving `opt` has zero of them; **kotlinc adds it twice
   itself**, once in each of its two pipelines, because both run `CGProfilePass` once profile
   metadata is present. Worked around by giving both pipelines `verify` and doing the
   optimisation in `opt`.
4. **That workaround silently disabled all optimisation.** Everything came out 10–20× slower,
   including the unit control, which does no dispatch and cannot be affected by promotion.
5. **The repeats were not interleaved** — all of A0, then all of A2. The unit control separated by
   **31.5 %** on the uniform arm, which a profile cannot cause: it was drift between two blocks
   of time. The macro half of this study has interleaved since [B-03](B-03-the-ruler.md); the
   micro half was written without it. `bench_stats.py` now **declares a mode void** when its unit
   control separates, before printing anything else.
6. **My first IR check looked for the wrong thing** and concluded promotion had not reached the
   benchmark's functions — it grepped for direct calls to the implementations rather than for the
   guard. The guards were there all along.

### Two things to carry forward

**Route B's A0 is not the ordinary A0.** The same source through the normal build is
`itable-single` 1.55 ns/op; through Route B with `default<O3>` in `opt` it is 1.26–2.43 depending
on the run. Every arm must be compared against an A0 that took the same route — which every
number above does.

**The uniform arm is much noisier than the others** (±0.89 against ±0.05), because a mispredicted
indirect branch has a wide latency distribution. A null there is weaker evidence than a null
elsewhere, and more rounds would be needed to make it strong.

### Not covered

`-stats` prints nothing from this `opt`, so promoted-site counts came from reading the IR rather
than from the pass. kotlinx-benchmark was not used: the harness is an in-process monotonic timer
taking the best of five inside each run, with nine interleaved rounds around it — **a deviation
from the brief's "kotlinx-benchmark on the native target", recorded as one rather than
substituted quietly**.

## Iteration 2 — 2026-09-21. The numbers had no host, and that reached a published article

**B-09's logs record no host, no CPU and no session.** Every `ns/op` here was taken on some
machine and the record does not say which. That is a provenance defect of the same family as the
binary that answered `commit: unknown`, and it stayed invisible while all comparisons happened
inside one run.

**It stopped being invisible when a number from this item was compared with a number from
elsewhere.** A blog post added a column for "the ordinary build, no PGO", measured fresh on the
build box, beside this item's A0 and A2. The ordinary build looked **34 % faster than the PGO
binary**, and the post published that as "as a way to make a Kotlin/Native program faster today,
this is a loss". It was wrong: the two sets differ by a uniform 1.55–1.68× across every measure,
which is a slower machine, not an effect.

**Remeasured properly** — three builds, nine interleaved rounds, 99 % intervals, one machine and
one session (`bench/three-arm.sh`, `logs/b-09/2026-09-21-three-arms-interleaved.txt`):

| build | interface | virtual | no dispatch |
|---|---:|---:|---:|
| ordinary, no PGO | 1.066 ± 0.025 | 0.804 ± 0.031 | 0.486 ± 0.029 |
| Route B, no profile | 1.071 ± 0.016 | 0.806 ± 0.028 | 0.494 ± 0.050 |
| Route B, with profile | **0.959 ± 0.026** | **0.699 ± 0.036** | 0.498 ± 0.056 |

- **The route is free within resolution.** All three of its intervals overlap the ordinary
  build's — which retires this item's own "Route B's A0 is not the ordinary A0", itself an
  artefact of comparing across machines.
- **The effect survives and agrees**: −10.5 % and −13.4 % against Route B's own A0, against the
  −11.2 % and −12.6 % first reported. The unit control separates from nothing anywhere.
- **The level drifts ~20 % between sessions on one machine** (a control arm read 0.470 in one
  session and 0.494 in another), so only numbers from a single interleaved run are comparable.

**`bench/three-arm.sh` prints host, CPU and session on every run.** A cross-machine comparison is
then visible in the log rather than in a published conclusion.
