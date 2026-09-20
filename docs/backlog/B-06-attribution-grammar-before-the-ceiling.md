---
id: B-06
title: "Fix the attribution grammar, with counts, before the ceiling is read"
status: done
priority: P0
size: S
stage: stage-1-ceiling
blocked_by: [B-02]
---

# B-06 — Fix the attribution grammar, with counts, before the ceiling is read

RQ1 is a gate whose whole content is a bucket table, and the brief's bucket rules are wrong twice
on this subject ([research §1.9](../research/research-architecture.md)):

- **"Symbols with the `kfun:` prefix" names one prefix of twelve.** In razves's subjects `kfun:`,
  `kclass:` and `kvar:` together were 12 125 of 23 336 Kotlin-prefixed ELF symbols. The other nine
  are mostly data and probably carry no self samples — probably is not a measurement, and this is
  a gate.
- **"Kotlin/Native C++ runtime symbols" cannot be drawn by mangling here.** The runtime is
  Itanium-mangled, and so is the Rust that `sqlx4k` links in, because Rust's legacy scheme
  produces `_ZN…` too. razves measured ~964 kB of `tokio`, `sqlx_postgres` and `core::ptr` landing
  in the Kotlin runtime under the naive rule. Arm A3 is defined by that same boundary, so the
  error would reach an arm and not only a table row.

- **The decision and its reason.** The grammar is fixed and published as counts before RQ1 is
  read, so that a bucket boundary cannot be adjusted after seeing which side of 40 % the number
  fell on. Buckets come from razves's owning-module attribution (amendment A1.4), not from
  mangling.
- The rejected alternative is a sixth attribution script written for this study. razves already
  charges every sample to exactly one row, including two rows for what it cannot name; a second
  counter is how two checks in one run come to report different numbers about the same file.
- Not covered: the kernel row, which no in-process attribution can supply and which
  [B-02](B-02-can-the-subject-host-be-profiled.md) decides.

- AC: the twelve Kotlin prefixes are enumerated for **this** subject's binary with a symbol count
  and a self-sample count each. H4 — that the eleven beyond `kfun:` carry under 1 % of samples —
  is confirmed or refuted with the number.
- AC: the runtime bucket and the Rust of `sqlx4k` are separated, and the separation is shown by
  naming a symbol that lands on each side.
- AC (positive control): a symbol known to belong to each of the five buckets is picked in advance
  and traced through the grammar to the row it lands in. A grammar that puts everything in one
  bucket satisfies every aggregate check.
- AC: razves's reconciliation identity and its unattributed and unparsed rows are printed beside
  the table. A bucket table that does not reconcile must be visible, not tidy.
- Anchors: `logs/b-06/`, `razves/README.md`, `xyk/server/build.gradle.kts`.

---

## Findings — 2026-09-20

**Done.** The grammar is [`scripts/attribution.py`](../../scripts/attribution.py) with its control
in [`scripts/attribution_control.py`](../../scripts/attribution_control.py). Both of the brief's
bucket rules turned out to need correcting, and **neither in the direction the amendments
assumed**.

### The symbol census: eight prefixes, and only one of them is code

`readelf -sW` over `xyk-pagedoff`, 31 639 entries:

| prefix | symbols | ELF type |
|---|---:|---|
| `kfun:` | 6 085 | **FUNC** |
| `kclass:` | 2 574 | OBJECT |
| `kifacevtable:` | 2 183 | OBJECT |
| `kifacetable:` | 2 162 | OBJECT |
| `krefs:` | 1 819 | OBJECT |
| `kintf:` | 1 636 | OBJECT |
| `kvar:` | 559 | OBJECT (558) + TLS (1) |
| `kassociatedobjects:` | 40 | OBJECT |

Eight, not razves's twelve — four of those are Apple-only and this is an ELF.

**Of the 11 804 `FUNC` symbols, every Kotlin-prefixed one is `kfun:`.** The other seven prefixes
are data: vtables, interface tables, reference tables, type info.

### H4 is confirmed, and for a structural reason rather than a statistical one

H4 asked whether the prefixes beyond `kfun:` carry under 1 % of self samples. They carry **zero**,
and not because they are small — they are 10 973 symbols against `kfun:`'s 6 085. They carry zero
because **a self sample lands on an instruction**, and `OBJECT` symbols have none.

**So amendment A1.3 is a no-op for RQ1, and it is still right for RQ6.** Widening the Kotlin
bucket from `kfun:` to all eight prefixes cannot change a self-sample share by a single sample.
[B-01](B-01-pins-and-the-amendment-window.md) recorded A1.3 as something that "can only enlarge
the Kotlin bucket, which moves RQ1 towards green" and tightened it for that reason; the tightening
was harmless and the worry was misplaced. Where the widening matters is **bytes** — 10 973 of
17 058 Kotlin symbols are data, so a size report keyed on `kfun:` alone would under-report Kotlin
by nearly two thirds. That is RQ6's problem and razves already solves it.

### A1.4's premise does not hold for this binary, and the reason is a Rust version

Amendment A1.4 rests on razves's finding that the Kotlin/Native runtime and Rust both mangle as
`_ZN…`, so the runtime bucket cannot be drawn by mangling. In `xyk-pagedoff`:

| | count |
|---|---:|
| Rust **legacy** mangling (`_ZN…17h<hash>E`) — the hazard | **0** |
| Rust **v0** mangling (`_R…`) | 1 274 |
| other Itanium C++ (`_Z…`) — genuinely the runtime | 301 |
| plain C identifiers — glibc, statically linked in | 4 144 |

The collision razves measured is absent here because this Rust emits v0, which is unambiguous.
**A1.4's rule stands and its stated reason does not** — the amendment says "define the bucket by
owning module because mangling cannot separate them", and on this subject mangling separates them
perfectly. It remains the safer rule, and the honest version of it is: *the hazard is real, it is
a property of the Rust version in the dependency, and it is not present at this one.*

Named on each side, as the AC asks: `_ZN6kotlin5alloc15CustomAllocator12CreateObjectEPK8TypeInfo`
is the runtime; `tokio::runtime::task::raw::poll` is `sqlx4k`'s Rust.

### The buckets, on a 60-second profile at the pinned rate through the two-host generator

86 073 leaf frames, `perf record -e cpu-clock -F 999`, generator on `bench-b` at 200 rps:

| bucket | samples | share |
|---|---:|---:|
| libc and other native | 30 194 | 35.08 % |
| kernel | 27 329 | 31.75 % |
| **`kfun:` — Kotlin code** | **17 912** | **20.81 %** |
| Kotlin/Native C++ runtime | 8 017 | 9.31 % |
| Rust (`sqlx4k`) | 1 976 | 2.30 % |
| vdso | 645 | 0.75 % |
| **total** | **86 073** | **100.00 %** |

**It reconciles exactly and the unresolved row is empty** — zero `[unknown]` outside vdso, against
the brief's 5 % discard rule.

### The control caught two broken rules that the table could not

A grammar that puts everything in one bucket still reconciles, still totals and still looks like a
measurement. Eleven symbols whose bucket was declared before the grammar ran:

**Two failed.** `bucket()` strips a leading underscore for Mach-O's `_kfun:`, and it stripped it
*before* the mangled-name tests — so `_ZN6kotlin…` and `_R…` never matched, and **the entire C++
runtime and all of Rust fell through to "libc and other native"**.

**The measured table above did not move when it was fixed**, because `perf` demangles Itanium and
Rust v0 by itself, so no mangled symbol ever reached the broken branch on this input. The bug was
latent here and would have fired the moment the grammar was pointed at a raw symbol table — which
is exactly what [B-15](B-15-second-sampler-for-the-ceiling.md) would have done.

### razves cannot be the instrument, and that corrects a decision rather than an amendment

AC4 asked for razves's reconciliation identity and its unattributed and unparsed rows beside the
table. **razves cannot read a `perf.data`.** Its `razves profile app.dump app.kexe` consumes a
dump written by the `:sampler` module **linked into the process**; the two are different samplers
with different input formats. [Research D3](../research/research-architecture.md) was written from
razves's README saying it turns "bytes **and samples**" into packages — true, and a different
claim.

AC4's *intent* is met by the grammar itself: it charges every frame to exactly one row, the rows
sum to the input, and what it cannot name has its own row. What is lost is the more valuable
thing — an **independent** second measurement — and that is
[B-15](B-15-second-sampler-for-the-ceiling.md), blocked on B-07 because a cross-check needs
something to check.

### What this is not

**20.81 % is not RQ1's answer**, though it is much closer to one than
[B-02](B-02-can-the-subject-host-be-profiled.md)'s 21.4 % was: the generator is on the right host
at the pinned rate, the grammar is fixed and controlled, and the sample is twelve times larger.
What it still is not: one endpoint rather than a majority of them, one 60-second window rather
than the interleaved protocol, and no GC log beside it. RQ1 is [B-07](B-07-rq1-the-ceiling.md) and
it is the item that gets to say green, grey or red.

That said, the number lands in the brief's grey band — above the 20 % red, well below the 40 %
green — and both independent profiles taken so far agree to within a percentage point.
