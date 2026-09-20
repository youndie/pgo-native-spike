---
id: B-14
title: "Make BRIEF.md's freeze checkable from the repository alone"
status: done
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

## Iteration 1 — 2026-09-20. Done, by the shape the item preferred

The received brief is [docs/research/source-brief.md](../research/source-brief.md), byte for
byte, and BRIEF.md links to it instead of embedding it. One copy; drift is not possible rather
than merely detectable.

- **AC — in the repository, checkable without any outside file.** `scripts/brief_freeze.py`
  hashes everything after a marker line: 18 849 bytes, `sha256 77d8480c…`. The wrapper above the
  marker is this repository's own prose and stays editable; the frozen text below it does not.
- **AC — exactly one copy.** The embedded duplicate is gone. **Before removing it, it was
  un-demoted and hashed independently of B-01** and came out identical to the received file, so
  the two copies were confirmed equal at the moment they became one.
- **AC (positive control) — a one-character edit fails.** Demonstrated against `make check`
  itself, not only in the script's self-test: one byte at offset 10 047 turned the gate red with
  the two digests printed side by side, and restoring the file turned it green again. The
  script's `--control` additionally covers a bare trailing newline (the case a tidying editor
  produces) and confirms that editing the **wrapper** is still allowed.
- **AC — the digest still matches after the move.** It is the same digest B-01 recorded; what
  changed is that checking it no longer needs the owner's `~/Downloads`.

**The received file still existed when this ran**, which is the only reason the move could be
verified rather than asserted. Had the item waited much longer the embedded copy would have been
the sole surviving text and "unedited" would have had to stand on B-01's word.

**One correction made in passing**, because it contradicted the repository it summarises:
`docs/README.md` still described the results document as *interim*, with "five of seven research
questions" and B-13 open. All three were stale.
