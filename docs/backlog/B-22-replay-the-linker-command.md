---
id: B-22
title: "Replay the linker command instead of resuming from bitcode"
status: done
priority: P0
size: M
stage: stage-2-feasibility
---

# B-22 — Replay the linker command the build prints

`-Xcompile-from-bitcode` **loses the native dependency graph**: `DependenciesTracker` builds
`nativeDependenciesToLink` from the klib graph during normal compilation, and a resume has no
klib graph. Supplying archives by hand does not fix it — passing librdkafka's five moved the
failure to `sqlx4k`'s symbols, and there is no reason to believe those are the last.

**The brief already said how to do this**: *"the link step is replayed from the command the
compiler prints"*. This item does that instead.

- **The decision and its reason.** Capture the full link command from a normal build, substitute
  the PGO-processed object for the compiler's own, and run it. The dependency list is then the
  build's, not this study's, and every arm inherits the identical link line by construction.
- **This also removes the reason the static link looked like a blocker.** Only the *training*
  binary links the profile runtime, and only that link hits `undefined hidden symbol: _DYNAMIC`.
  A0 and A3 link no profile runtime at all, so they stay exactly as pinned.
- The rejected alternative is continuing to pass archives by hand. It is unbounded, and each one
  added is a way for two arms to differ.
- Not covered: the training binary's own linkage. If it must be dynamic to carry the profile
  runtime, that is acceptable — **a profile is keyed by function name and CFG hash, neither of
  which depends on how the binary was linked**, so the training arm's linkage cannot reach the
  comparison.

- AC: A0 and A3 built through a replayed link, byte-identical in their link lines apart from the
  object being linked.
- AC: **A0-static against A0-dynamic measured once**, at eight counted rounds, so that if the
  training arm's linkage ever does matter the size of it is known rather than assumed.
- AC (control): A0 through the replayed link lands within the ruler of A0 through the ordinary
  build. A replay that changes the number is not a replay.
- Anchors: `logs/b-22/`, `pgo-native-spike/bench/build-arm.sh`, `xyk/server/build.gradle.kts`.

## Iteration 1 — 2026-09-20. The replay is exact, and it exposes a better wall

`recipe/replay-link.sh` does the item's decision, and was run (`logs/b-22/`).

- **AC met, more strongly than asked.** Replaying the captured line with the compiler's own
  object reproduces the ordinary build **byte for byte**. The AC asked for "within the ruler of
  A0 through the ordinary build"; an identity does not need a measurement.
- **The training arm works end to end.** Instrumented bitcode carries no profile metadata, so
  kotlinc runs its own full pipeline and **emits the object even when its own link fails**. The
  replayed line plus the profile runtime yields a binary that runs and writes an IR-level
  profile. This is the path [B-21](B-21-rq0-the-two-numbers.md) needs.
- **AC 2 is moot and was not run.** A0-static against A0-dynamic existed to size the assumption
  that the training arm's linkage cannot reach the comparison. Only the training binary links the
  profile runtime, so no measured arm's linkage changes at all; and A2.3 dropped the macro arms,
  so nothing is left for the difference to contaminate.
- **The use arm is walled off, and the wall is a better finding than the one this item opened
  on.** A module carrying profile metadata makes kotlinc emit `CG Profile` twice — its LTO
  pipeline and its `clang++` codegen step — and rejects its own module. Neither copy comes from
  the input. The only `-Xllvm-lto-passes` that avoids it does no LTO, and Kotlin/Native's LTO
  internalises 3 027 defines to 411, which `opt -passes=default<O3>` does not reproduce: the
  externally optimised binary is 3.8× the ordinary build's size. An A3 arm built this way is not
  comparable to the pin.

**Two defects in the script, both caught by its own `ERR` trap** before anything was reported:
the profile-runtime flags were appended as a *new line* rather than onto the link line, so the
link ran without the runtime and every `__llvm_profile_*` symbol came back undefined; and the
first version took the object by a glob that matched before checking one existed.
