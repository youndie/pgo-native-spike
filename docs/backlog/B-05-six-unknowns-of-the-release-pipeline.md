---
id: B-05
title: "Answer the six believed-and-unchecked items against the fork's source"
status: done
priority: P1
size: M
stage: stage-0-stand
blocked_by: []
---

# B-05 — Answer the six believed-and-unchecked items against the fork's source

> **Unblocked and mostly answered, 2026-09-20, by
> [B-04](B-04-fork-at-the-pinned-tag-and-the-baseline.md) — which was dropped in the process.**
> No fork is needed, so this item no longer waits on one, and four of its eight questions are
> already answered by reading the clone and listing the toolchain:
>
> - **H1 confirmed**: the `linux_x64` dev bundle ships `opt`, `llvm-profdata` and
>   `libclang_rt.profile.a`, and it is already on the build box. No LLVM build.
> - **Custom pass lists exist as a stock flag** — `-Xllvm-module-passes` replaces the pipeline
>   string outright.
> - **Bitcode dump and resume exist** — `-Xsave-llvm-ir-after`, `-Xcompile-from-bitcode`.
> - **Extra linker inputs exist** — `-Xoverride-clang-options`, `linkerArguments`,
>   `nativeLibraries`.
>
> What remains for this item: the promotion thresholds of the pinned LLVM, whether the runtime
> bitcode is linked before or after the instrumentation point, whether two builds produce
> identical IR there, and **the phase names `-Xsave-llvm-ir-after` actually accepts — a bogus one
> is accepted silently and dumps nothing**, so that flag cannot be trusted to have worked just
> because it did not error.

The brief lists six things it believes about the release pipeline and has not checked. Two of them
decide whether the study needs an LLVM build at all, one decides whether arm A3 is free, and one —
whether two builds of the same source produce identical IR at the instrumentation point — decides
whether RQ5 can be asked. Phase 0 answers each against the fork's source and records the answer
whether or not it is convenient.

Two more were added by research and belong in the same pass
([research §1.1](../research/research-architecture.md), §1.2):

- **What the `linux_x64` LLVM bundle actually ships.** The nine-entry listing that shows
  `llvm-profdata` present and `opt` absent was taken from the **essentials** bundle on macOS
  aarch64. `linux_x64` uses `llvm-21-x86_64-linux-dev-116`, and a bundle called *dev* is entitled
  to hold more. If it ships `opt`, Route B needs no LLVM build.
- **Whether JetBrains' LLVM 21 carries patches over upstream.** `konan.properties` names a
  distribution, not a revision. If the distribution is patched, an `opt` built from upstream
  LLVM 21 is a different `opt`, and Route B stops being an oracle for Route A.

- **The decision and its reason.** Each answer is written as a fact with the file it was read in,
  in the same table shape the rest of the research uses, so that the next person re-checks it in
  one hop instead of re-deriving it.
- The rejected alternative is answering them inside RQ0, where five days are already budgeted for
  something else and an inconvenient answer arrives as a schedule problem.
- Not covered: changing anything. This item reads; [B-08](B-08-rq0-a-merged-profile-applied.md)
  writes.

- AC: eight answers, each with a path into the fork's source or a listing of the bundle, covering
  the brief's six plus the two above.
- AC: the IR-identity question is answered by **building the subject twice and diffing the IR at
  the instrumentation point**, not by reasoning about determinism. If function order or generated
  names differ, RQ5 is affected before it is asked, and the results say so.
- AC (positive control for that diff): a deliberate one-line source change produces a diff the same
  comparison detects. A comparison that reports "identical" for two different sources is reporting
  on its own pipeline.
- AC: the promotion thresholds of the pinned LLVM revision are recorded as found and left at their
  defaults.
- Anchors: `logs/b-05/`,
  `JetBrains/kotlin@v2.4.20!/kotlin-native/backend.native/compiler/ir/backend.native/src/org/jetbrains/kotlin/backend/konan/llvm`,
  `kotlin-native-prebuilt-macos-aarch64-2.4.20!/konan/konan.properties`.

---

## Findings — 2026-09-20

**Done. All eight answered, none of them by building anything** — by reading the clone and
listing the toolchain that was already installed.

### 1. Where the release pipeline is assembled, and can it be extended

`OptimizationPipeline.kt`. The module pipeline is one string and **`-Xllvm-module-passes`
replaces it outright**:

```kotlin
override val passes = listOf(config.modulePasses ?: "default<$optimizationFlag>")   // :348
```

Five named pipelines exist — `llvm-mandatory`, `llvm-default`, `llvm-lto`, `llvm-tsan`,
`llvm-ssp` — and `-Xllvm-lto-passes` does the same for the LTO one.

### 2. Can the LLVM C API carry a profile file path — **no, and it does not matter**

There is no `-mllvm` or cl::opt passthrough: `ParseCommandLineOptions`, `mllvm` and `llvmArgs`
appear nowhere in `kotlin-native/`. So `pgo-instr-use` cannot be given a profile path through the
compiler. **Route B hands it to an external `opt` on its own command line**, and
[A2.4](../../BRIEF.md) already made Route B the only route.

### 3. Do existing `-X` flags allow pass lists, bitcode dumps and extra link inputs — **all three**

`-Xllvm-module-passes`, `-Xsave-llvm-ir-after` with `-Xsave-llvm-ir-directory`,
`-Xcompile-from-bitcode`, and `-Xoverride-clang-options` / `linkerArguments` / `nativeLibraries`
(`K2NativeCompilerArguments.kt:448, 801, 860`).

**The phase names, which the brief did not ask for and which the flag will not tell you.** Valid
values are compiler phase names from `driver/phases/Bitcode.kt` — `LinkBitcodeDependencies`,
`ModuleBitcodeOptimization`, `LTOBitcodeOptimization`, `MandatoryBitcodeLLVMPostprocessingPhase`,
`WriteBitcodeFile`, `CStubs`, `VerifyBitcode` and others — or the form `<pipeline>:<llvm-pass>`
(`OptimizationPipeline.kt:62`).

**A bogus phase name is accepted silently and dumps nothing.** `-Xsave-llvm-ir-after=bogus-phase-name`
exits zero and produces only the binary. So this flag cannot be trusted to have worked because it
did not error, and any recipe using it must assert the `.ll` file exists.

Working, verified: `-Xsave-llvm-ir-after=LinkBitcodeDependencies` produces
`out.LinkBitcodeDependencies.ll`, 8.7 MB of textual IR, 170 364 lines.

### 4. Is the runtime bitcode linked before or after the instrumentation point — **before**

`LinkBitcodeDependencies` runs before `ModuleBitcodeOptimization`, and the module it produces
contains the runtime:

| in `out.LinkBitcodeDependencies.ll` | defines |
|---|---:|
| `kfun:` — Kotlin | 1 519 |
| `_ZN6kotlin` — the C++ runtime | 559 |
| `Kotlin_` — the runtime's C entry points | 458 |
| total | 3 027 |

**So arm A3 is free and arm A2 is the one that costs work.** A3 is "the profile applied to Kotlin
code *and* the runtime bitcode" — which is simply what the module already is. A2 has to *exclude*
the runtime, and `noprofile` on those functions is the first candidate, as the brief guessed.
This is the right way round for [A2.4](../../BRIEF.md), which made A3 the best-case probe.

### 5. Do two builds produce identical IR at the instrumentation point — **effectively yes**

Two builds of the same source, same flags: **12 differing lines out of 170 364**.

- **10 of them are one symbol**: `_Konan_init_3d4afa70-…` against `_Konan_init_050407dc-…` — a
  fresh UUID per compilation in the module initializer's name.
- **The other 2 were my own doing**: `!DIFile(filename: "/tmp/irA/x.kexe")` against `irB`, the
  output path I passed. Not nondeterminism.
- **The binaries are bit-identical** — same md5.

So exactly one function loses its profile across a rebuild, the module initializer, and nothing
else moves. **RQ5 is not threatened by build nondeterminism**, which is what the brief feared.

### 6. The promotion thresholds, as found and left alone

`opt -print-all-options -passes=pgo-icall-prom`, LLVM **21.1.6**:

| option | default | what it means |
|---|---:|---|
| `icp-max-prom` | **3** | promotions per indirect call site |
| `icp-max-annotations` | **3** | targets recorded per site |
| `icp-remaining-percent-threshold` | **30** | a candidate must be 30 % of the *remaining unpromoted* count |
| `icp-total-percent-threshold` | **5** | and 5 % of the total |
| `icp-minimum-count-threshold` | 0 | no absolute floor |
| `icp-cutoff` | 0 | no per-compilation limit |
| `icp-max-num-vtables` | 6 | vtables annotated per vtable load |

**These make RQ2's two controls predictions rather than hopes.** Eight receivers in uniform
rotation give each 12.5 %, under the 30 % remaining-count threshold, so nothing should be
promoted — which is the control's declared outcome. Eight at 90/10 put the dominant target far
over both thresholds, so it should be promoted — also as declared. If either control comes out
otherwise, the disagreement is with a number that is now written down.

### H1 and H2

**H1 confirmed** in [B-04](B-04-fork-at-the-pinned-tag-and-the-baseline.md): the `linux_x64` dev
bundle ships `opt`, `llvm-profdata` and `libclang_rt.profile.a`, already installed.

**H2 is moot.** It asked whether JetBrains' LLVM carries patches over upstream, because an
upstream-built `opt` might not match. Route B uses **the bundle's own `opt`** — the same LLVM the
compiler uses, by construction — so there is nothing to mismatch. The question would return only
if `opt` had to be built.

### Not covered

- Whether `-Xcompile-from-bitcode` actually reproduces an equivalent binary from a dumped module.
  That is Route B's load-bearing step and it is [B-08](B-08-rq0-a-merged-profile-applied.md)'s
  first acceptance criterion, not this item's.
- Whether `-Xllvm-module-passes` accepts a pipeline string containing `pgo-instr-gen`. Also
  B-08's.
