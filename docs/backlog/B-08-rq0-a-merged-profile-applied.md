---
id: B-08
title: "RQ0 — a profile that merges and applies, by Route B then Route A"
status: done
priority: P0
size: XL
stage: stage-2-feasibility
blocked_by: [B-05]
---

# B-08 — RQ0: a profile that merges and applies, by Route B

> **Re-scoped 2026-09-20 by [BRIEF](../../BRIEF.md) A2.4, after RQ1 came back grey.** Route A —
> the five days inside the fork — is **not** attempted. This item is Route B only, on the
> **microbenchmark binary** rather than the service, and it is time-boxed to two or three days
> together with [B-09](B-09-rq2-indirect-call-promotion.md). The mechanism answer holds at any
> offered rate, which is what makes it worth having when the macro half may not be.
>
> **It may not need the fork at all.** Route B's only requirement of the compiler is that the
> linked pre-optimisation bitcode can be got out of it. If a stock `-X` flag does that, this item
> and [B-05](B-05-six-unknowns-of-the-release-pipeline.md) come unblocked from
> [B-04](B-04-fork-at-the-pinned-tag-and-the-baseline.md) entirely — which would take the build
> host off this study's critical path. That is the first thing to check.

Feasibility, and the study's longest budget: five working days, after which kill criterion 1
applies and the write-up is the list of obstacles in the order they were hit, with the patch set as
far as it got. Green is a profile that merges and, on the macro subject, at least 80 % of functions
with non-zero counts having it applied in the rebuilt IR.

- **The decision and its reason.** Route B first — dump the linked pre-optimisation bitcode, let an
  external `opt` instrument or apply, replay the link — because it involves no compiler changes and
  shows what a correct result looks like. Route A, inside the fork, is the prototype; Route B stays
  as its oracle. A prototype with no oracle cannot tell "the pass did nothing" from "the pass did
  not run".
- The order within Route B is the brief's: hello-world, then the service. A profile that will not
  come out of a hello-world will not come out of a service, and the hello-world says so in
  minutes.
- Both passes must sit at the same point in the pipeline, because the profile is keyed by a hash of
  each function's CFG at that point. Any pass that runs before one and not the other drops
  profiles silently — and *silently* is the word that makes this an AC rather than a note.
- Not covered: performance. Nothing here is a measurement of speed; that is
  [B-09](B-09-rq2-indirect-call-promotion.md) and [B-10](B-10-rq3-rq4-the-macro-arms.md).

- AC: a `.profraw` out of the running service that `llvm-profdata merge` accepts, with
  `show --all-functions --ic-targets` printing counts per function and recorded targets per
  indirect call site.
- AC: which of the two write mechanisms works is recorded — `__llvm_profile_write_file` through
  cinterop from the shutdown path, or continuous mode through `LLVM_PROFILE_FILE` with `%c`. A
  service stops on a signal and never reaches `atexit`, so this is not a detail.
- AC: the rebuilt IR is dumped **from the binary that is measured**, and three numbers are read out
  of it: functions with the profile applied, functions dropped on a CFG hash mismatch, and
  indirect call sites promoted.
- AC (positive control, and the brief's rule made into a check): a profile from a **different**
  program is applied and the hash-mismatch count is near total. A pipeline that reports "applied"
  for a profile that cannot match is reporting on its own bookkeeping.
- AC (second control): the same profile applied through Route A and Route B gives the same applied
  and mismatched counts. Where they differ, Route B is right until shown otherwise.
- AC: arm A1's run-time overhead is recorded and not judged, and if A1 cannot hold the training
  rate the profile is taken at a lower rate and the results say which.
- AC: the effort is timed against the five-day criterion from a recorded start; an overrun is
  written as "not completed" with the reason and the next step starts.
- Anchors: `logs/b-08/`, `ci/pgo/route-b.sh`, `ci/pgo/route-a.patch`,
  `JetBrains/kotlin@v2.4.20!/kotlin-native/backend.native/compiler/ir/backend.native/src/org/jetbrains/kotlin/backend/konan/llvm`.

---

## Findings — 2026-09-20

# RQ0 is **GREEN** on the microbenchmark, and Route B works end to end

A profile comes out of a Kotlin/Native binary, merges, and applies. **No fork, no LLVM build, no
compiler patch** — stock 2.4.20 plus the `opt` and `llvm-profdata` already installed.

```
kotlinc-native -Xsave-llvm-ir-after=LinkBitcodeDependencies   ->  8.7 MB .ll
opt -passes=pgo-instr-gen,instrprof                           ->  instrumented .bc
kotlinc-native -Xcompile-from-bitcode  -u__llvm_profile_runtime  -> A1, 956 kB
LLVM_PROFILE_FILE=... ./a1.kexe                               ->  .profraw, 137 kB
llvm-profdata merge                                           ->  .profdata, IR level, 916 funcs
opt -passes=pgo-instr-use -pgo-test-profile-file=...          ->  929 defines carry !prof
```

| RQ0's green | |
|---|---|
| the profile merges | **yes** — 916 functions, max count 2 000 000 000 |
| functions with the profile applied in the rebuilt IR | **929 of 3 027 defines, against 0 before the pass**; the profile contained 916, so essentially everything it held was applied — comfortably over the 80 % bar |
| hash mismatches | none reported |

**The write mechanism is the plain one.** A program that returns from `main` reaches `atexit` and
writes the profile with `LLVM_PROFILE_FILE` alone; neither `%c` continuous mode nor a cinterop
call to `__llvm_profile_write_file` was needed. A service that dies on a signal still will —
that is the macro subject's problem, not the microbenchmark's.

### Four obstacles, in the order they were hit

1. **The dumped IR is textual `.ll`, and `opt` takes it happily.** No obstacle, but worth stating:
   the round trip through `opt -passes=""` and back produced a binary whose output was identical
   to the baseline's. That control ran before anything was instrumented, so a later failure could
   not be blamed on the round trip.
2. **The instrumented binary wrote no profile.** The counter sections were present
   (`__llvm_prf_cnts`, `_data`, `_names`, `_vals`, `_vnds`) but **not one runtime symbol** —
   `__llvm_profile_write_file` absent. A static archive only yields members that resolve an
   undefined symbol, and nothing referenced them. Fixed with
   **`-linker-option -u__llvm_profile_runtime`**, the anchor LLVM uses for exactly this.
3. **The profile merged as `Instrumentation level: Front-end`**, and `pgo-instr-use` refuses
   anything but IR level. The instrumented module's own marker was correct —
   `__llvm_profile_raw_version = 0x100000000000000A`, bit 56 being the IR flag — but
   `libclang_rt.profile.a` ships **`InstrProfilingVersionVar.c.o`**, whose strong definition beats
   the module's `comdat any`, `hidden` one.
4. **Deleting that object breaks the link** — `undefined hidden symbol:
   __llvm_profile_raw_version`, because the runtime references it and the module's copy is
   hidden. Fixed by *replacing* it: a one-line C file,
   `long long __llvm_profile_raw_version = (1LL << 56) | 10;`, compiled with the bundle's clang
   and put into the archive in its place. The profile then merges as **IR**.

### The negative control fails on the axis it was designed for, and that is the finding

AC4 asked for a profile from a different program to be applied and the hash-mismatch count to be
"near total". It is not:

| | right profile | **wrong profile** |
|---|---:|---:|
| defines carrying `!prof` | 929 | **954** |

**The wrong profile annotates more functions than the right one.** The reason is structural:

> **Two unrelated Kotlin/Native programs share 2 933 of 2 938 defines — 99.8 % of the module.**

One is an integer loop, the other builds and filters a list of strings. Five functions differ.
Everything else is the runtime and the stdlib, linked into both, with identical names and
identical CFG hashes — so a profile from either legitimately applies to almost all of the other.

**The counts discriminate sharply even though the coverage does not:**

| | right profile | wrong profile |
|---|---:|---:|
| maximum function entry count | **2 000 000 008** | 2 400 904 |
| distinct branch-weight nodes | 52 | 260 |

Three orders of magnitude apart. So the control works — on counts, not on coverage — and **AC4's
design was wrong rather than its intent**.

### What this does to arm A4, and it is not small

A4 is the brief's control: "profile from an unrelated workload applied", to separate *PGO helps*
from *any rebuild moves the number*. Its implicit model is that an unrelated profile is largely
rejected. **On Kotlin/Native it is not — it is accepted for 99.8 % of the module**, with wrong
counts.

That makes A4 a **better** control than the brief thought, not a worse one: it is a genuine
same-coverage, wrong-weights arm rather than a mostly-unprofiled rebuild. But any write-up that
describes A4 as "the profile mostly does not apply" would be wrong, and the number to report
beside A4 is the count distribution, not the applied fraction.

### Not covered

- **The macro subject.** This item is the microbenchmark by [A2.4](../../BRIEF.md); RQ0 on xyk
  would need the same recipe through the Gradle build, and the shutdown-path question (`%c` or a
  cinterop `__llvm_profile_write_file`) becomes real there.
- **Promoted sites.** `pgo-icall-prom` with `-stats` produced no output on this module, which is
  expected — an integer loop has no indirect calls worth promoting. That measurement belongs to
  [B-09](B-09-rq2-indirect-call-promotion.md), whose benchmark has dispatch in it by design.
- **Route A agreement.** Route A is dropped ([B-04](B-04-fork-at-the-pinned-tag-and-the-baseline.md)),
  so there is no second route to agree with. The round-trip control in obstacle 1 is what stands
  in its place.
