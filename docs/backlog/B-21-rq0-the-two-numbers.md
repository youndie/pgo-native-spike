---
id: B-21
title: "RQ0's two missing numbers, and the macro subject its green requires"
status: done
priority: P1
size: M
stage: stage-2-feasibility
blocked_by: [B-22]
---

# B-21 — RQ0's two missing numbers

[B-08](B-08-rq0-a-merged-profile-applied.md) reported RQ0 green. **It is grey**, for two reasons
that were visible in the item itself.

1. **The brief defines green "on the macro subject".** B-08 ran on the microbenchmark. A2.4
   re-scoped the *item*; it did not move the threshold.
2. **The numbers reported are not the pre-registered ratio.** 916 functions in the profile and
   929 annotated defines are two different sets — one counts the profile, the other counts the
   module — and 929 being the larger shows they cannot be a ratio of applied to applicable.

The threshold names two quantities and neither was computed: **functions with non-zero counts
that had the profile applied**, and **functions dropped on a CFG hash mismatch**. The second is
also what the brief requires beside any null result, so it is owed twice.

- **The decision and its reason.** Compute both by intersecting the profile's function list with
  the annotated defines by name, rather than by counting each side separately. The mismatch count
  comes from `pgo-instr-use`'s own remarks, which have to be asked for — a silent pass is not
  evidence of zero.
- Not covered: re-running RQ0 on the microbenchmark. That result stands as a mechanism
  demonstration; what it cannot do is satisfy a threshold written about the service.

- AC: both numbers, on the macro subject, with the ratio stated against the 80 % line.
- AC (control): the same two numbers computed for a **deliberately mismatched** profile, where
  the mismatch count must be near total. A counter that reports zero mismatches for a profile
  that cannot match is counting nothing.
- Anchors: `logs/b-21/`, `pgo-native-spike/logs/b-08/README.md`.

## Narrowed — 2026-09-20, by B-13

**Two of this item's three unknowns are closed.** Both numbers were computed on the
microbenchmark by `scripts/profile_applied.py` (which has a control in `make check`), against the
recipe's own run on bench-a — 934 functions in the profile, **171 with a non-zero counter, 170
applied, 0 dropped on a hash mismatch** (`logs/b-13/`).

What remains is the third: **the brief defines RQ0's green on the macro subject**, and there is
no macro binary until [B-22](B-22-replay-the-linker-command.md) produces one. The method is no
longer in question and costs a second to run, so this item is now that single dependency.

Two findings from computing them, which the next run needs:
- Kotlin mangled names contain `(`, `#` and `{}` and are emitted as **quoted** LLVM symbols. A
  define regex that stops at the first `(` truncates every Kotlin name and reports the program as
  missing from its own module. This was hit and is encoded in the reader's control.
- PGO prefixes internal-linkage symbols with `<module>;` in the profile. Compared name for name,
  13 of 171 looked dropped and none were.

## Iteration 1 — 2026-09-20. Done. RQ0 is green

Both numbers, on the macro subject, from **4 480 real requests** across all four endpoints
(`logs/b-21/`):

| | |
|---|---:|
| functions in the profile | 13 285 |
| **with a non-zero counter** | **5 763** |
| **profile applied** | **5 762** |
| **dropped on a CFG hash mismatch** | **0** |
| **share applied, against the 80 % line** | **99.98 %** |

The single non-applied entry is named `out;`, which is not a function. **RQ0's pre-registered
green is met in every clause** and the verdict table is updated.

**AC (control) met, and it was worth insisting on.** With every CFG hash flipped by one bit and
names and counters untouched, `opt` emits **13 784** hash-mismatch warnings against the true
profile's **0**; `!prof` in the module falls from 24 387 to **140**; the applied count goes to
**0** and the reader's mismatch count to **5 762**. Both instruments move together in both
directions, so the zero is a measurement rather than a silence.

**The binary is the first real use of [B-22](B-22-replay-the-linker-command.md)'s replayed
link**, and two things had to be established on the way:

- **The replay is byte-identical on the service**, not just on the toy — it reproduced the
  20 169 448-byte pinned binary exactly.
- **The training arm cannot use the pinned static link.** The profile runtime needs a dynamic
  executable, and dropping `-static` is not enough: `-Bstatic … -lc` remains and the loader
  rejects the result outright (*"IFUNC symbol 'memset' … unsatisfiable circular dependency"*).
  It uses a non-static build's link line instead, which is sound **because the two builds' IR is
  byte-identical** — checked, at 71 103 473 bytes each, not assumed.

**A third parser trap, and it changed the answer.** The first run said 5 522 applied and 241
absent, all generic functions. **LLVM escapes non-ASCII bytes in quoted symbol names**, and
Kotlin mangles a type parameter with `U+00A7`: the module spells it `\C2\A7`, `llvm-profdata`
prints it raw. After unescaping, 5 762. That is the third distinct way this one reader was
defeated by Kotlin's mangling, after parentheses inside quoted names and the `<module>;` prefix;
all three are cases in `--control`, which `make check` runs.

**One number kept from building the control:** the 13 286 profiled functions carry only **2 366
distinct CFG hashes**. A hash match is weaker evidence of identity on this platform than the
mechanism's name suggests, which is an argument for the name-and-hash intersection this item
specified rather than a count from either side alone.

**Not claimed:** the condition says *in the rebuilt IR*, and that is what was measured. A rebuilt
binary carrying the profile is blocked by B-22's `CG Profile` finding, and RQ0's green does not
ask for one.
