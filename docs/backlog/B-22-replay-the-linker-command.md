---
id: B-22
title: "Replay the linker command instead of resuming from bitcode"
status: open
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
