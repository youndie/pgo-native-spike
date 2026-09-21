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

## Iteration 1 — 2026-09-21, corrected twice

Trained on `6359a88`, applied to earlier revisions' IR. **Each row is the distance from the
trained revision, not from its neighbour.** 5 763 non-zero functions, 1 457 158 189 counters:

| revision | Ktor | distance | retained, functions | retained, **weight** | hash mismatch |
|---|---|---|---:|---:|---:|
| `6359a88` | 3.6.0 | self | 99.983 % | **100.000 %** | 0 |
| `c4ba99f` | 3.6.0 | 1, build only | 99.965 % | **100.000 %** | 0 |
| `5c701e4` | 3.6.0 | 2 | 99.896 % | **99.999 %** | 3 |
| `f0e5980` | 3.6.0 | 3 | 99.584 % | **99.968 %** | 8 |
| **`c62412d`** | **3.5.2** | **4, across the version boundary** | **96.460 %** | **99.683 %** | **78** |

- **AC met** — five revisions, applied and mismatch counts for each.
- **AC (control) met** — a build-only commit retains **100.000 % by weight**.
- **`opt`'s warnings track the reader independently**: 0, 0, 8, 15, 170.

### Correction 1 — the framework bump was in no comparison

This item first labelled `f0e5980` as "Ktor 3.5.2 → 3.6.0" and built a headline on it.
**`f0e5980` is the commit that introduced 3.6.0**, so it and every later revision carry the same
version and the bump was on neither side. `c62412d` was added to fix that, and crossing the
boundary costs an order of magnitude more: **0.317 % of weight against 0.032 %**, 78 hash
mismatches against 8.

The conclusion survives with a bigger number: **99.683 % of a profile's information lands across
a framework minor version and four commits** — on the single transition measured, which is not a
rate for framework bumps in general.

### Correction 2 — weighting, and "names do not drift" withdrawn

Counting functions treats a cold lambda and a hot function alike; `scripts/profile_applied.py`
now also sums counters, with a control case. And of the 16 functions absent by name at
`f0e5980`, **11 carry a generated-name marker** — all `ingestModule$2…` lambdas in the module
that changed — for a combined **19 counters of 1.46 billion**. Names do change; they are cold.

### What moves a hot function's hash, confirmed in the IR and then in a clean build pair

`DeferScope#executeAllDeferred` alone is **442 333 of the 468 374** counters lost at `f0e5980`.
Its source did not change and neither did the Kotlin version. In `6359a88` the IR carries a
two-arm `kclass` comparison over the deferred lambdas; in `f0e5980`, one arm and no comparison.

**Isolated afterwards**, because that pair differs by three commits: two trees from the same
revision, differing **only** by one added `defer { }` lambda. Binary 20 169 472 → 20 170 456
bytes, and two untouched stdlib symbols move (`logs/b-24/2026-09-21-devirtualisation.log`):

| symbol | base | one extra lambda |
|---|---:|---:|
| `kotlinx.cinterop.ArenaBase#clearImpl` | 283 B | **331 B** |
| `refTo$$inlined$usingPinned$1…getPointer$1.invoke` | 223 B | **297 B** |

Both are the `DeferScope` machinery, neither was edited. **Kotlin/Native's closed-world
devirtualisation expands `invoke` into a chain of type guards whose arm count tracks the set of
lambdas reachable in the whole program**, so adding one anywhere rewrites shared stdlib code.

**The difference from C and C++ is pass order, not the absence of the transformation.** C++ has
LTO and `-fwhole-program-vtables` doing the same class of rewriting; what differs is that
LLVM takes the profile hash **early, before the inliner and before whole-program
devirtualisation**, whereas Kotlin/Native devirtualises **in the frontend, before LLVM IR
exists** — so every `opt`-reachable instrumentation point is downstream of it. **A profile hash
here is a property of the program's composition rather than of the function's source.**

That also means it cannot be fixed by choosing a different instrumentation point. The only lever
is disabling the phase: `-Xdisable-phases` exists, but **the phase name and its cost were not
established** — `-Xlist-phases` printed nothing on 2.4.20.

**Direction.** The brief asks for the *next* commits; the trained revision is the branch tip, so
earlier ones are used. Agreement is symmetric, but a forward test would additionally see names
that only new code introduces.

**What this does not say.** RQ5's green is retained *effect*, not retained coverage. That half
needs RQ3.
