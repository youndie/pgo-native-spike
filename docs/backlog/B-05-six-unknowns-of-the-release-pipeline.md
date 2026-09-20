---
id: B-05
title: "Answer the six believed-and-unchecked items against the fork's source"
status: open
priority: P1
size: M
stage: stage-0-stand
blocked_by: [B-04]
---

# B-05 — Answer the six believed-and-unchecked items against the fork's source

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
