---
id: B-14
title: "Make BRIEF.md's freeze checkable from the repository alone"
status: open
priority: P2
size: XS
stage: stage-0-stand
---

# B-14 — Make BRIEF.md's freeze checkable from the repository alone

[BRIEF.md](../../BRIEF.md) claims to carry the brief as received, unedited. On 2026-09-20
[B-01](B-01-pins-and-the-amendment-window.md) verified that claim and recorded the digest, but the
check needed the received file, which lives in the owner's `~/Downloads` and will not survive.
From the moment it is deleted the freeze is an assertion the repository cannot support — and the
freeze is the entire reason a pre-registration is worth having.

- **The decision this item has to take, and it is small but real.** Either commit the received
  brief as its own file and have BRIEF.md link to it rather than embed it — zavarnik's shape, one
  copy, drift impossible — or keep the embedded copy and add a checker that compares it against a
  committed original, which is two copies plus machinery to manage the duplication they create.
  The first is the better answer and is the one to take unless something argues otherwise.
- The rejected alternative is the digest alone, which is what exists now. It lets somebody who
  already holds the file confirm it and tells everyone else nothing.
- Not covered: the pins and the amendments, which are this repository's own text and are not
  frozen in the same sense — they were written here and their history is in git.

- AC: the received brief is in the repository, and the claim "unedited" is checkable without any
  file outside it.
- AC: there is exactly one copy of the brief's text in the repository. If the chosen shape leaves
  two, a check compares them and is in `make check`.
- AC (positive control): a one-character edit to the received text makes the check fail. A freeze
  check that passes whatever it is given is the same as no freeze check.
- AC: the digest recorded in BRIEF.md still matches after the move, or the move says why it
  changed.
- Anchors: `pgo-native-spike/BRIEF.md`, `pgo-native-spike/Makefile`,
  `zavarnik/docs/research/source-brief.md`.
