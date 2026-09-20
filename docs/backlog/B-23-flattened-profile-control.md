---
id: B-23
title: "Replace A4 with a flattened profile, which carries no information"
status: dropped
priority: P1
size: S
stage: stage-4-macro
---

# B-23 — A flattened profile, as the control A4 was meant to be

Arm A4 — "a profile from an unrelated workload" — rests on a model
[B-08](B-08-rq0-a-merged-profile-applied.md) measured to be false. **Two unrelated Kotlin/Native
programs share 2 933 of 2 938 defines, 99.8 % of the module.** An unrelated profile is therefore
mostly a *correct* profile for the runtime and the stdlib, and differs only on the handful of
functions the two programs do not share. As a control for "is the gain profile-guided?" it is
weak by construction.

- **The decision and its reason.** Flatten the trained profile instead: export it with
  `llvm-profdata merge --text`, set every counter to one value, convert it back. **Every function
  then has a profile and none of them carries information.** If the flattened build matches A2,
  the gain is not profile-guided — which is precisely what A4 was for, without depending on two
  programs being genuinely different.
- The rejected alternative is keeping A4 as written. It would still be reported, and it would
  still be read as "the profile mostly does not apply", which is false here.
- Not covered: whether a flattened profile is *identical* to no profile. It is not — the counts
  are uniform rather than absent, so branch weights exist and are equal, and hotness-scaled
  inlining sees a flat world rather than no world. That difference is the point and is stated
  with the result.

- AC: the flattened profile is shown to be flat — every counter equal — before it is used.
- AC: the flattened build measured against A2 and A0 at eight counted rounds.
- AC (control on the control): the flattened profile still **applies** to as many functions as
  the trained one. A flattening that accidentally invalidated the profile would produce the same
  null for the wrong reason.
- Anchors: `logs/b-23/`, `pgo-native-spike/logs/b-08/README.md`.

## Dropped — 2026-09-20, by B-13

**Its consumer is gone, and its question is answered elsewhere.** A4 is a macro arm: the brief
scores it inside RQ3 ("A4 within the ruler of A0") and runs it interleaved with A2 and A3. A2.3
dropped Route A, so there is no macro comparison for a flattened profile to be the control of.

**And the question it was raised to answer — is the gain profile-guided, or does any rebuild move
the number? — is already answered on the micro half**, by a control that was in the data before
this item was written. The uniform-rotation and 90/10 measurements come from the same pair of
binaries. A layout or rebuild effect is a property of the binary and would move both. It moves
90/10 by −11.2 % and leaves uniform +5.2 %, intervals overlapping. That is the discrimination
A4 was for.

Kept as a design note rather than deleted: the reasoning about why an "unrelated workload"
profile is a weak control on Kotlin/Native — two unrelated programs share 99.8 % of their
defines — is a property of the platform, not of this study, and the next person to write an A4
into a Kotlin/Native brief needs it.
