---
id: B-23
title: "Replace A4 with a flattened profile, which carries no information"
status: open
priority: P1
size: S
stage: stage-4-macro
blocked_by: [B-22]
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
