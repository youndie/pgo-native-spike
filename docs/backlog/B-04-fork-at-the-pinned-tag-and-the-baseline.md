---
id: B-04
title: "Build the fork at v2.4.20, and prove it is a valid baseline"
status: open
priority: P0
size: L
stage: stage-0-stand
blocked_by: [B-01]
---

# B-04 — Build the fork at `v2.4.20`, and prove it is a valid baseline

Kill criterion 2: a binary from the unmodified fork must land within the ruler of a binary from the
stock distribution of the same release. If it does not within two working days, nothing built from
the fork can be compared with anything and the study stops outright. The threat is real and named
in the brief — a different host compiler, different flags or different LLVM build options shift the
baseline — and it is the criterion whose failure invalidates every later number rather than
answering a question.

- **The decision and its reason.** The tag is `v2.4.20`, not the version sborka builds itself with
  ([research §1.1](../research/research-architecture.md)). Kotlin/Native is built from that source
  on the Linux box; the mac is a draft editor with 16 GB and 41 GB of disk and will not hold a
  compiler build.
- The rejected alternative is a stock distribution with flags. The pipeline has to be changed, and
  a stock distribution cannot be — the brief's own reason, kept.
- Not covered: keeping the fork alive across Kotlin releases. The brief calls that a product
  decision, not a research result, and the fork tracks one tag and is not rebased.

- AC: `JetBrains/kotlin` at `v2.4.20` builds a Kotlin/Native that compiles the subject to a
  `linux_x64` release binary.
- AC: that binary and one from the stock 2.4.20 distribution are run through
  [B-03](B-03-the-ruler.md)'s protocol, interleaved, and the difference is **within the ruler**,
  with the ruler's own number printed beside it. "Within the ruler" is a comparison against a
  measured quantity, not a judgement.
- AC (positive control): the pair is also compared on something that must differ — binary size per
  owner with `razves`, or the compiler version string in the binary — so that a harness which
  compared a binary with itself by mistake is caught. Two builds that agree on everything are as
  likely to be one build measured twice.
- AC: the build is recorded as a script and a patch set, not as a shell history. The brief's
  deliverable is a recipe.
- AC: the effort is timed against the two-day criterion, from a recorded start.
- Anchors: `logs/b-04/`, `ci/fork/build-kotlin-native.sh`,
  `JetBrains/kotlin@v2.4.20!/kotlin-native/README.md`.
