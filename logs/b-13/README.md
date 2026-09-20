# B-13 — the recipe, run on a clean host, and RQ0's two numbers

`recipe/pgo.sh` was run end to end on **bench-a** (`ubuntu-8gb-nbg1-1`, 7.0.0-30-generic), a host
that had never built anything in this study, against `recipe/example.kt`. All seven steps passed:

    IR 8 803 235 bytes, 3 044 defines -> 38 338 __profc_ references -> libprofile-ir.a (19 objects)
    -> 1 profraw (136K) -> 934 functions, max count 20 021 000 -> !prof 134 -> 1410

**Two things had to be fetched or fixed to get there, and both are in the script now.**

1. **The `dev` LLVM bundle is a separate download and it is the one with `opt`.** A normal
   Kotlin/Native install pulls `llvm-21-x86_64-linux-essentials-116`, which has `clang`,
   `llvm-ar` and `llvm-profdata` but no `opt` — and `opt` is what runs both PGO passes.
   `konan.properties` names the dev bundle in `llvm.linux_x64.dev`. It is reachable at
   `download.jetbrains.com` even from these IPv6-only hosts, where `cache-redirector.jetbrains.com`
   has no AAAA record at all.
2. **`-Xsave-llvm-ir-directory` needs the directory to exist.** If it does not, kotlinc prints
   `warning: cannot dump LLVM IR to non-existent location`, writes nothing, and **exits 0**.

## Both load-bearing steps were verified by removing them

Neither claim rests on the recipe having worked once:

| removed | result |
|---|---|
| `-linker-option -u__llvm_profile_runtime` | links, runs, **writes no `.profraw` at all** |
| the replaced version object (stock `libclang_rt.profile.a`) | profile merges as **`Instrumentation level: Front-end`**; `pgo-instr-use` refuses it: *"Not an IR level instrumentation profile"* |

## RQ0's two numbers, on the microbenchmark

By `scripts/profile_applied.py`, which has its own control (`--control`, wired into `make check`):

| | |
|---|---:|
| functions in the profile | 934 |
| ... with a non-zero counter | 171 |
| **... of those, profile applied** | **170** |
| **... dropped on a hash mismatch** | **0** |
| ... no longer a define (inlined or not emitted) | 1 |

The single non-applied entry is named `out;` — a profile entry with an empty name after the
module prefix, not a function.

**This does not make RQ0 green.** The brief defines RQ0's green *on the macro subject*, and this
is the microbenchmark; see [B-21](../../docs/backlog/B-21-rq0-the-two-numbers.md). What it does
settle is that the two numbers are obtainable and what they cost to obtain: the reader is 130
lines and runs in a second on a 3 000-define module.

Raw: `profile-applied.txt`, `show-all.txt.gz` (the full per-function counter dump).
