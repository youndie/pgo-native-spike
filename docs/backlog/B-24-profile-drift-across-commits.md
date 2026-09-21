---
id: B-24
title: "RQ5's structural half: how much of a profile survives the next commits"
status: done
priority: P1
size: S
stage: stage-5-durability
---

# B-24 — How much of a profile survives a code change

RQ5 asks how long a profile lives, and the brief scores it as *"at least two thirds of the RQ3
effect retained"* — which needs RQ3, and RQ3 is blocked in the toolchain. **But the question has
a structural half that needs no macro arm at all**: apply a trained profile to the IR of other
revisions and count what still lands. It answers what the brief was really worried about — do
generated names for lambdas and anonymous classes drift between builds, and how much of a
profile does a typical commit cost?

- **The decision and its reason.** Reuse `scripts/profile_applied.py` from
  [B-21](B-21-rq0-the-two-numbers.md) and the profile it trained. No new instrument, no new
  measurement protocol, and the answer is about the toolchain rather than about this stand.
- The brief says the *next* three commits. The trained revision is the tip, so the three
  **preceding** commits that touch `server/src` are used instead. The question — does a profile
  survive a revision of the same program — is unchanged by direction.
- Not covered: **the performance half of RQ5.** How much of the *effect* is retained cannot be
  had without RQ3, and this does not stand in for it.

- AC: the profile applied to at least three other revisions, with applied and hash-mismatch
  counts for each.
- AC (control): a revision that changes no code retains essentially everything. A drift figure
  that is large even where nothing changed is measuring the harness.
- Anchors: `logs/b-24/`, `pgo-native-spike/scripts/profile_applied.py`.

## Iteration 1 — 2026-09-21. A profile survives a code change almost intact

Trained on `6359a88`, applied to each revision's IR. 5 763 functions carry non-zero counts:

| revision | what changed | applied | retained | hash mismatch | no longer a define |
|---|---|---:|---:|---:|---:|
| `6359a88` | nothing — self | 5 762 | **99.98 %** | 0 | 1 |
| `c4ba99f` | build only, no source | 5 761 | **99.97 %** | 0 | 2 |
| `5c701e4` | one feature commit | 5 757 | **99.90 %** | 3 | 3 |
| `f0e5980` | **Ktor 3.5.2 → 3.6.0** | 5 739 | **99.58 %** | 8 | 16 |

- **AC met** — four revisions, applied and mismatch counts for each.
- **AC (control) met** — `c4ba99f` changes no source and retains 99.97 %, one function away from
  the self-application. The measurement is not dominated by harness noise.
- **`opt`'s own warnings track the reader**: 0, 0, 8, 15 against the reader's 0, 0, 3, 8. Not
  equal — `opt` warns about zero-count functions too, the reader counts only non-zero ones — but
  the same direction and order, from two independent counts.

**The answer to what the brief was worried about: generated names do not drift.** A profile
trained on one revision still applies to **99.58 %** of its non-zero functions across a **minor
Ktor version bump**, which is a larger change than a typical commit. Name mangling for lambdas
and anonymous classes is stable enough that profile staleness is not the thing that limits how
long a profile lives on this platform.

**What this does not say.** RQ5's green is about *retained effect*, not retained coverage. A
profile can apply to 99.58 % of functions and still be worth less, because the counts inside it
describe a workload and a code shape that have moved. That half needs RQ3 and stays blocked.
