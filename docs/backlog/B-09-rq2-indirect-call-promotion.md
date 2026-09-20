---
id: B-09
title: "RQ2 — does indirect call promotion fire on Kotlin dispatch, and what is it worth"
status: wip
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
