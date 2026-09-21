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

Trained on `6359a88`, applied to each revision's IR. 5 763 functions carry non-zero counts and
1 457 158 189 counters between them:

| revision | what changed | retained, **functions** | retained, **weight** | hash mismatch |
|---|---|---:|---:|---:|
| `6359a88` | nothing — self | 99.983 % | **100.000 %** | 0 |
| `c4ba99f` | build only, no source | 99.965 % | **100.000 %** | 0 |
| `5c701e4` | one feature commit | 99.896 % | **99.999 %** | 3 |
| `f0e5980` | **Ktor 3.5.2 → 3.6.0** | 99.584 % | **99.968 %** | 8 |

- **AC met** — four revisions, applied and mismatch counts for each.
- **AC (control) met** — `c4ba99f` changes no source and retains **100.000 % by weight**.
- **`opt`'s own warnings track the reader**: 0, 0, 8, 15 against 0, 0, 3, 8 — not equal, since
  `opt` warns about zero-count functions too, but the same direction and order.

**Weighting was added after review and it changes the reading.** Counting functions treats a cold
lambda and a hot function alike. By counter weight the Ktor bump costs **0.032 %** rather than
0.42 % — the loss is an order of magnitude smaller than the function count implies, because what
stops matching is cold. `scripts/profile_applied.py` now reports both, with a control case.

**Generated names do change, and iteration 1 of this item said they do not.** Of the 16 functions
absent by name at the Ktor bump, **11 carry a generated-name marker** — every one an
`ingestModule$2…` lambda, in the single module whose code actually changed. That is name
instability under a code change, not gratuitous drift, and **their total weight is 19 counters of
1.46 billion**.

**The expensive losses are CFG changes in hot shared code.** The eight hash mismatches carry
467 209 of the 468 374 lost counters, and `kotlinx.cinterop.DeferScope#executeAllDeferred` is
442 333 of them alone. That — not naming — is what a framework bump costs a profile.

**Direction.** The brief asks for the *next* three commits; the trained revision is the branch
tip, so the three **preceding** ones are used. Name and hash agreement is symmetric between two
revisions, but a forward test would additionally see names that only new code introduces, and
this does not.

**What this does not say.** RQ5's green is about *retained effect*, not retained coverage. A
profile can apply to 99.968 % of the weight and still be worth less, because the counts inside it
describe a workload and a code shape that have moved. That half needs RQ3.
