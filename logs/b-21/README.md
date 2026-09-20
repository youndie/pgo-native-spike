# B-21 — RQ0's two numbers, on the macro subject. RQ0 is green

**The pre-registered condition**, unedited: *"On the macro subject: the profile merges, and at
least 80 % of functions with non-zero counts have it applied in the rebuilt IR."*

| | |
|---|---:|
| functions in the profile | 13 285 |
| **... with a non-zero counter** | **5 763** |
| **... of those, profile applied** | **5 762** |
| **... dropped on a CFG hash mismatch** | **0** |
| ... no longer a define | 1 — the entry named `out;`, which is not a function |
| **applied, as a share of the line** | **99.98 %** against 80 % |

The profile merges as `Instrumentation level: IR`, 13 286 functions, maximum count 101 657 230,
from **4 480 real requests** across all four endpoints of the running service.

## How the binary was built, which is the part that was blocked all study

[B-22](../../docs/backlog/B-22-replay-the-linker-command.md)'s replayed link, used on a real
service for the first time:

- **The replay is byte-identical on the service too**, not only on the toy: replaying the
  captured `ld.lld` line with the compiler's own object reproduced the 20 169 448-byte pinned
  binary exactly.
- **The pinned build is static and the profile runtime needs a dynamic executable.** Stripping
  `-static` from the static line is not enough — it leaves `-Bstatic … -lc`, and the loader
  refuses: *"IFUNC symbol 'memset' referenced in libm.so.6 is defined in the executable and
  creates an unsatisfiable circular dependency"*. The training arm therefore replays the link
  line of a **`-Pxyk.staticLink=false`** build.
- **That is sound because the two builds' IR is byte-identical** — checked, not assumed: both
  produce the same 71 103 473-byte `out.LinkBitcodeDependencies.ll`. `staticLink` does not reach
  the IR, so a profile trained on the dynamic binary is a statement about the pinned module.

## The control, which is why the zero is believable

A zero mismatch count is what a counter that counts nothing also reports. The same two numbers
were computed for a profile that **cannot** match: every CFG hash flipped by one bit, names and
counters untouched.

| | true profile | every hash flipped |
|---|---:|---:|
| `opt` hash-mismatch warnings | **0** | **13 784** |
| `!prof` metadata in the module | 24 387 | **140** |
| applied, of 5 763 non-zero | **5 762** | **0** |
| hash mismatch, by the reader | 0 | **5 762** |

Both instruments agree in both directions, and `opt`'s own remark is the pre-registered source:
*"function control flow change detected (hash mismatch) … count discarded"*.

**One number worth keeping from building that control:** the 13 286 profiled functions carry
only **2 366 distinct CFG hashes**. A Kotlin/Native module is full of small functions of
identical shape, so a hash match is weaker evidence of identity here than the mechanism's name
suggests — which is an argument for the name-and-hash intersection this item asked for rather
than a count from either side alone.

## A third parser trap, and the reason the first answer was wrong by 241

The first run reported **5 522 applied and 241 absent**, all of them generic functions. They were
not absent: **LLVM escapes non-ASCII bytes in quoted symbol names**, and Kotlin mangles a type
parameter with `U+00A7` — which the module spells `\C2\A7` and `llvm-profdata` prints raw. Every
generic function in the module therefore looked missing from it.

That is the third distinct way Kotlin's mangling defeats a naive comparison in this one reader,
after parentheses inside quoted names and the `<module>;` prefix on internal linkage. All three
are now cases in `scripts/profile_applied.py --control`, which `make check` runs.

## What this does not claim

The condition says **"in the rebuilt IR"**, and that is what was measured. A rebuilt *binary*
carrying the profile is a different thing and is blocked by B-22's `CG Profile` finding. RQ0's
green does not ask for one.

Raw: `2026-09-20-rq0-macro.log`.
