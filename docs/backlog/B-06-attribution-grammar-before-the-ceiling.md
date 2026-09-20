---
id: B-06
title: "Fix the attribution grammar, with counts, before the ceiling is read"
status: wip
priority: P0
size: S
stage: stage-1-ceiling
blocked_by: [B-02]
---

# B-06 — Fix the attribution grammar, with counts, before the ceiling is read

RQ1 is a gate whose whole content is a bucket table, and the brief's bucket rules are wrong twice
on this subject ([research §1.9](../research/research-architecture.md)):

- **"Symbols with the `kfun:` prefix" names one prefix of twelve.** In razves's subjects `kfun:`,
  `kclass:` and `kvar:` together were 12 125 of 23 336 Kotlin-prefixed ELF symbols. The other nine
  are mostly data and probably carry no self samples — probably is not a measurement, and this is
  a gate.
- **"Kotlin/Native C++ runtime symbols" cannot be drawn by mangling here.** The runtime is
  Itanium-mangled, and so is the Rust that `sqlx4k` links in, because Rust's legacy scheme
  produces `_ZN…` too. razves measured ~964 kB of `tokio`, `sqlx_postgres` and `core::ptr` landing
  in the Kotlin runtime under the naive rule. Arm A3 is defined by that same boundary, so the
  error would reach an arm and not only a table row.

- **The decision and its reason.** The grammar is fixed and published as counts before RQ1 is
  read, so that a bucket boundary cannot be adjusted after seeing which side of 40 % the number
  fell on. Buckets come from razves's owning-module attribution (amendment A1.4), not from
  mangling.
- The rejected alternative is a sixth attribution script written for this study. razves already
  charges every sample to exactly one row, including two rows for what it cannot name; a second
  counter is how two checks in one run come to report different numbers about the same file.
- Not covered: the kernel row, which no in-process attribution can supply and which
  [B-02](B-02-can-the-subject-host-be-profiled.md) decides.

- AC: the twelve Kotlin prefixes are enumerated for **this** subject's binary with a symbol count
  and a self-sample count each. H4 — that the eleven beyond `kfun:` carry under 1 % of samples —
  is confirmed or refuted with the number.
- AC: the runtime bucket and the Rust of `sqlx4k` are separated, and the separation is shown by
  naming a symbol that lands on each side.
- AC (positive control): a symbol known to belong to each of the five buckets is picked in advance
  and traced through the grammar to the row it lands in. A grammar that puts everything in one
  bucket satisfies every aggregate check.
- AC: razves's reconciliation identity and its unattributed and unparsed rows are printed beside
  the table. A bucket table that does not reconcile must be visible, not tidy.
- Anchors: `logs/b-06/`, `razves/README.md`, `xyk/server/build.gradle.kts`.
