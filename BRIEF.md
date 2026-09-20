# BRIEF — instrumentation PGO for Kotlin/Native

> **Role of this document: the pre-registration.** It records what was decided *before* the first
> measurement, so that a threshold cannot be moved to fit a number after the fact. Everything below
> the brief as received on 2026-09-20 is [docs/research/source-brief.md](docs/research/source-brief.md),
> byte for byte and gate-checked. Amendments are appended here with a date and a reason; nothing
> is edited away.

**Budget:** the per-step budgets of the brief's Kill criteria — five working days for RQ0, two for
RQ1, one per RQ2 dispatch shape, three for RQ3 and RQ4 together, two for RQ5, half a day for RQ6.
**Owner:** Pavel (youndie).
**Output:** `docs/research/<date>-instrumentation-pgo.md`, the patch set, and raw logs under
`logs/`.

**The pins the brief left as placeholders**, resolved before the first measurement and not
re-resolved afterwards:

| Row | Pin | Where it came from |
|---|---|---|
| Kotlin release the stand carries | **2.4.20** | sborka `0.4.0.86`'s published `wip` catalog, which is where the subject takes its compiler |
| Fork tag | `JetBrains/kotlin` at **`v2.4.20`**, commit **`890ac1d94fdb80eb85f0eeb5be5e4352df987b2f`** | `git ls-remote --tags`, 2026-09-20. The commit is recorded beside the tag because a tag is a movable reference and a baseline that moves is not a baseline |
| LLVM bundled by that release | **21**, distribution `llvm-21-x86_64-linux-dev-116` | `konan.properties` of the 2.4.20 toolchain |
| Macro subject | **xyk** — Kotlin/Native, Ktor CIO, sqlx4k/SQLite in process | owner's choice, 2026-09-20; it is the only portfolio subject that already has the two-host stand |
| Subject build options | **`-Pxyk.httpClient=false -Pxyk.outbound=real -Pxyk.staticLink=true -Pxyk.allocator=paged-off`** — the ingest-only, statically linked, paged-off build | `xyk/server/build.gradle.kts` lines 28–44 name all four axes and their defaults; this is the arm xyk's own two-host measurement was taken on, so the ruler priors describe the same binary |
| Hosts | xyk's pair, as ssh destinations: **`SUBJECT=bench-a`**, **`GENERATOR=bench-b`** — both 4 cores, kernel `7.0.0-30-generic` | supplied by the owner 2026-09-20 and probed the same day; `xyk/bench/` takes these two names and refuses to take a number on one host. See amendment A1.2 |
| Ktor / coroutines | 3.5.2 / 1.11.0 | the same catalog |

**Provenance of the frozen text.** The brief as received is `sha256
77d8480c45cba5eae46d7f46f7006a23fe336492bb43a54f7902c87608859a77`, 18 849 bytes, and it lives at
[docs/research/source-brief.md](docs/research/source-brief.md). **`make check` verifies that
digest on every run** (`scripts/brief_freeze.py`, whose own control shows a one-character edit
failing), so the freeze is checkable by anyone holding this repository and nothing else. It was
first verified on 2026-09-20 against the received file by
[B-01](docs/backlog/B-01-pins-and-the-amendment-window.md), and again, independently, by
[B-14](docs/backlog/B-14-make-the-freeze-checkable-from-the-repo.md) at the moment the embedded
duplicate was removed.

## Amendments

Made on 2026-09-20, **before the first measurement**, each with the measurement elsewhere in the
portfolio that motivated it. The window closes at the first measurement of this study. The
evidence for every one of them is in
[docs/research/research-architecture.md](docs/research/research-architecture.md).

### A1.1 — the macro unit is read from pinned-core occupancy, with `utime+stime` beside it

The brief's Macro unit row says `utime+stime` over the clean window divided by responses. The JIT
phase measured that estimate overstating by **6.4–7.2 % on its host, constantly**, and wrote the
recommendation for future stands into its own research: take the cost per request from the
occupancy of the pinned cores in `/proc/stat`, which is bounded above by physics and converges with
the truth at saturation. Both numbers are recorded; the core-occupancy one is the unit of the
verdict. Ratios between arms survive either way — the amendment protects the absolutes, which are
what a published µs-per-request figure is.

### A1.2 — the "two-host protocol of the JIT phase" is xyk's protocol, and is pinned as such

The brief's Hosts row cites a protocol the JIT phase did not run. That phase's own research records
that the subject and the generator shared all twenty cores in **every** configuration, including
the one its article called pinned. The protocol the brief describes — subject host and generator
host, a fixed offered rate, arms interleaved, the first round discarded as warm-up — is xyk's, run
on 2026-09-16. It is pinned by that name, and it brings one thing the brief does not ask for and
this study needs: **the generator's own ceiling is established per endpoint before any arm is
compared**, so that a number is not read off a saturated generator.

### A1.3 — the Kotlin bucket is every Kotlin symbol prefix, and the list is written down first

The brief's attribution table defines Kotlin code as "symbols with the `kfun:` prefix".
Kotlin/Native emits **twelve** `k…:` prefixes; in razves's subjects `kfun:`, `kclass:` and `kvar:`
together were 12 125 of 23 336 Kotlin-prefixed ELF symbols. The others are mostly data — vtables,
interface tables, type info — and are unlikely to carry self samples, but "unlikely" is not the
same as measured. The bucket is `^_?k[a-z]+:`, the twelve prefixes are enumerated in the results
with their sample counts, and if the eleven beyond `kfun:` carry under 1 % of samples the results
say so and the distinction stops mattering *with a number behind it*.

**This widening can only enlarge the Kotlin bucket, which moves RQ1 towards green, so it is not
allowed to stand alone.** The `kfun:`-only share is published beside the widened one, and RQ1's
verdict is stated against both. A reader who prefers the brief's literal rule gets its verdict
without recomputing anything, which is what stops a corrected definition from doing a threshold's
work.

### A1.4 — the Runtime bucket is defined by owning module, not by mangling

The brief's table separates "Kotlin/Native C++ runtime symbols" from "libc and other native". On
this subject that boundary cannot be drawn by mangling: the Kotlin/Native runtime is Itanium-mangled
(`_ZN…`), and so is the Rust that `sqlx4k` links in, because Rust's legacy scheme produces `_ZN…`
too. razves measured about **964 kB** of `tokio`, `sqlx_postgres` and `core::ptr` landing in the
Kotlin runtime under the naive rule. The bucket is therefore taken from the symbol's owning object
or klib, which razves already attributes. **This is also the definition of arm A3** — "the runtime
bitcode" — so the same correction fixes an arm, not only a table row.

### A1.5 — the kernel row is conditional, and says so rather than going missing

RQ1's instrument is `perf record -e cpu-clock`. On the portfolio's other Linux host `perf` is a
stub not built for that kernel and `/proc/*/schedstat` returns zeros; whether the cloud subject
host differs is unverified and is the first thing checked. If it cannot run, the kernel row is
reported as **not measured**, RQ1's thresholds are applied to the stated user-mode denominator, and
the write-up carries that qualification next to every RQ1 number.

**And a missing kernel row inflates the Kotlin share**, because it leaves the denominator: on a
profile where the kernel is a third of samples, dropping it multiplies every other bucket by
about 1.5. So with the kernel row missing **RQ1 cannot be reported green — grey at best**, and the
results say which condition it missed. A gate whose instrument is missing is not allowed to read
as a pass, and that includes reading as a pass by arithmetic.

## Amendment set 2 — after the first measurement, by the owner (2026-09-20)

**These break the rule the first set was written under, and the break is deliberate and named.**
Amendments A1.1–A1.5 were made before anything was measured, which is what made them legitimate.
This set is made after RQ1 and the ruler, and the owner's reason is that **the thresholds
themselves were mis-sized against a bar that did not exist when they were written**:

> "I set the 40 % and 20 % thresholds against a 5 % macro bar, before the ruler existed. At the
> measured bar of 9.3 % with four rounds, even a green RQ1 could not clear it: a 15 % return on a
> 40 % bucket is 6 % of a request."

That is an incoherence rather than an inconvenient number. None of what follows moves a threshold
to fit a result; A2.1 makes the protocol stricter, A2.2 fills a hole the brief left open, A2.3
adds a stopping rule that did not exist, and A2.4 is the one that lowers a bar — by adding
evidence rather than by relaxing a standard. Each is declared **before** the run it governs.

### A2.1 — a macro run is eight counted rounds, not four

At four counted rounds [B-03](docs/backlog/B-03-the-ruler.md) measured the ruler at ±4.6 %, so
`max(5 %, 2 × ruler)` is **9.3 %** — above anything PGO returns, and above what even a green RQ1
could produce. At eight counted rounds the ruler is ±2.44 % and the bar is the brief's own 5 %
floor. **On the three endpoints that do real work, the grey verdict of RQ1 is red in practice at
four rounds.**

### A2.2 — the offered rate is chosen by a rule, and the run must be shown unsaturated

The brief fixes "one number per endpoint" and never says how the number is chosen, which is the
same hole the JIT phase's RQ0 had. Both ends of the range distort the gate:

- **Saturated** inflates the Kotlin share — measured, and by a factor of 3.7: `/journal` read
  55.55 % saturated against 14.92 % clean ([B-07](docs/backlog/B-07-rq1-the-ceiling.md)).
- **Near-idle** inflates the kernel share, because wakeups dominate, and deflates everything
  else. 200 rps on a four-core box is close to idle.

**The rule: each endpoint runs at 50–70 % of its own saturation rate**, and every run states its
delivered rate against its offered rate and its p50. A run whose delivered rate is below its
offered rate, or whose p50 has left the flat part of the curve, is not used.

### A2.3 — the drop rule for Route A, declared before the measurement it decides

**If Kotlin self plus runtime stays under 40 % on every work endpoint at the rate A2.2 fixes,
Route A, RQ5 and RQ6 are dropped.** Kotlin self plus runtime is the most arm A3 can touch, so it
is the ceiling on the ceiling.

Applied to the numbers that already exist — at the old rate, which A2.2 says is the wrong one —
the rule would **not** fire: `/api/events` 40.69 %, `/journal` 46.24 %, `/hooks/{id}` 33.46 %.
That is recorded here so the rule cannot later be read as having been chosen to produce a
foregone conclusion.

### A2.4 — the work is re-ordered, and most of the brief is now conditional

Route A's five days are not spent yet. In order:

1. **Unblock off-host builds** ([B-16](docs/backlog/B-16-unblock-off-host-builds.md)). Every arm
   and the GC log need a rebuilt xyk and `bench-a` cannot produce one.
2. **A second RQ1 point** ([B-17](docs/backlog/B-17-rq1-second-point.md)), half a day, under
   A2.2, with one `--call-graph dwarf` capture per endpoint to fix the inclusive column.
3. **The mechanism, through Route B only** ([B-08](docs/backlog/B-08-rq0-a-merged-profile-applied.md),
   [B-09](docs/backlog/B-09-rq2-indirect-call-promotion.md)), on the microbenchmark binary,
   time-boxed to two or three days. RQ2's answer holds at any offered rate, and this is what
   "fork, study, prototype" is for.
4. **One best-case macro probe** ([B-10](docs/backlog/B-10-rq3-rq4-the-macro-arms.md)): **A3
   against A0**, through Route B, on the most favourable endpoints, at eight rounds. A3 is the
   upper bound because it covers Kotlin code *and* the C++ runtime, and the C and C++ prior of a
   5–15 % return genuinely applies to the runtime. **A null here stops the study**: A2 cannot
   succeed where A3 fails, and A4 is only needed to explain a positive result.
5. **If positive, resume the brief as written.**

### A2.5 — where the CPU actually goes is logged outside the verdicts

`_int_malloc`, `__libc_calloc` and `malloc_consolidate` are **glibc** functions, and this binary
carries Kotlin/Native's own allocator. Something is calling libc malloc heavily, and the
candidates are Ktor and kotlinx-io native-heap buffers, the runtime's own C++ containers, SQLite,
and the Rust component. A2.4's dwarf capture names the owner.

An `LD_PRELOAD` of jemalloc or mimalloc is a **one-hour probe that needs no compiler work**
([B-18](docs/backlog/B-18-allocator-probe.md)). Allocator changes are a non-goal of this brief, so
the probe is recorded outside the verdicts — it is the natural RQ1 of the next study, and its
plausible effect is larger than the best case for PGO.

---

## Amendment set 3 — the fork is not needed (2026-09-20)

**A3.1 — the "Compiler" and "LLVM tools" rows of the fixed setup are wrong at this version, and
kill criterion 2 is moot.**

The brief says *"The pipeline has to be changed, and a stock distribution cannot be"* and
*"built from the exact LLVM revision that Kotlin/Native release bundles"*, implying a fork and an
LLVM build. Neither is required:

- The stock 2.4.20 compiler exposes **`-Xllvm-module-passes`**, which *replaces the module
  optimization pipeline string outright*, plus `-Xsave-llvm-ir-after`, `-Xcompile-from-bitcode`,
  `-Xllvm-variant` and three ways to add linker inputs.
- **`llvm-21-x86_64-linux-dev-116` — the exact bundle `konan.properties` names — is already on
  the build host**, with `opt`, `llvm-profdata`, `libclang_rt.profile.a`, and `opt --print-passes`
  listing `pgo-instr-gen`, `pgo-instr-use`, `instrprof` and `pgo-icall-prom`.

So [B-04](docs/backlog/B-04-fork-at-the-pinned-tag-and-the-baseline.md) is **dropped**, and with
no fork there is no second toolchain to validate: **kill criterion 2 cannot fire and is not
tested.** Kill criteria 1, 3, 4, 5 and 6 are untouched.

**What is still out of reach without a patch, and why it does not bite.** There is no `-mllvm`
passthrough, so `pgo-instr-use` cannot be handed a profile path from the compiler's command line.
Route B applies the profile with an external `opt`, which takes the path on its own command line,
and A2.4 already made Route B the only route this study takes. If Route B proves unusable, Route
A and the fork both return.

### A3.2 — that last clause has half fired: Route B's **use** arm is unusable on a service

Recorded 2026-09-20 after [B-22](docs/backlog/B-22-replay-the-linker-command.md), and it
qualifies A3.1 rather than reversing it. A3.1 is correct that the stock compiler exposes every
flag the mechanism needs, and RQ0 and RQ2 were both carried on stock tools with no fork. But
Route B has two arms and only one of them survives contact with a real module:

- **Instrument and train: stock is enough.** Instrumented bitcode carries no profile metadata,
  kotlinc runs its own pipeline on it, and replaying the printed link command produces a training
  binary that writes an IR-level profile.
- **Apply: stock is not enough.** A module carrying profile metadata makes kotlinc emit the
  `CG Profile` module flag twice — from its LTO pipeline and from its `clang++` codegen step —
  and reject its own module. Neither copy comes from the input. The only `-Xllvm-lto-passes`
  value that avoids the collision does no LTO, and Kotlin/Native's LTO internalises and
  dead-strips 3 027 defines to 411, which no external `default<O3>` reproduces.

**What this does to the record.** Kill criterion 2 stays untested — there is still no fork, and
none was built. But *"the fork is not needed"* was too broad: it is not needed to instrument,
train, merge or apply-to-a-module, and it **is** the plausible fix for the one step that stops a
service arm. That is a finding about the toolchain and it goes in the results document; **it does
not restart Route A**, which A2.3 dropped on a bucket measurement that has nothing to do with
this and would be unaffected if the wall vanished tomorrow.

---

---

## The brief as received

**It is not embedded here any more; it is [docs/research/source-brief.md](docs/research/source-brief.md),
byte for byte, and it is the only copy in this repository.**

It used to sit below this line with its headings demoted one level so as to nest under this
section. That worked, and B-01 verified it reproduced the received digest, but it made the frozen
text a *second* copy that a tidying edit could silently move — and the demotion meant the file
could never be hashed as it stood. Before the copy was removed it was un-demoted and hashed once
more, independently of B-01: 18 849 bytes, `sha256 77d8480c…`, identical.

Now `scripts/brief_freeze.py` hashes the received bytes where they lie, `make check` runs it, and
a one-character edit fails the gate. **The claim "unedited" no longer depends on a file in
anybody's `~/Downloads`** — which is what it rested on from 2026-09-20 until this was done.
