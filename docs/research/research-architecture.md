---
id: research-architecture
title: Instrumentation PGO for Kotlin/Native — study architecture research
type: research
status: active
date: 2026-09-20
---

# Research: what is already known before this study starts

The study asks whether LLVM instrumentation PGO can be made to work on a Kotlin/Native service
binary from a fork of the toolchain, and how much request CPU it removes. The brief and its
thresholds are in [BRIEF.md](../../BRIEF.md). This document says what was already measured
elsewhere in the portfolio, what follows from it, and which of the brief's rows had to be resolved
or restated **before** the first measurement because they name something other than what they mean.

Verified facts are separated from hypotheses on purpose. A fact here cites the artefact or the
document it was read in. A hypothesis says where it will be checked and by which backlog item.

Nothing here is a measurement of this study. **Every number below was taken on another subject,
another host, or another platform**, and is used only to size a threshold or to order the work.
Where an item of this study has since contradicted something here, the correction is written **at
the point of divergence** and marked as one, keeping the reason the first idea was wrong.

---

## 1. Verified facts

### 1.1 The compiler the subject carries, and the LLVM inside it

| Fact | Where verified |
|---|---|
| The portfolio's compiler comes from the `wip` catalog that a sborka release publishes; the subject pins `sborka = "0.4.0.86"` and declares no `kotlin` of its own | `xyk/gradle/libs.versions.toml`, lines 2–5 |
| That catalog carries **`kotlin = "2.4.20"`**, `ktor = "3.5.2"`, `coroutines = "1.11.0"` | `io.github.youndie.sborka:catalog:0.4.0.86!/catalog-0.4.0.86.toml` lines 11, 15, 17 |
| Kotlin/Native 2.4.20 declares **LLVM 21** for `linux_x64` (`llvmVersion.linux_x64=21`) | `kotlin-native-prebuilt-macos-aarch64-2.4.20!/konan/konan.properties:793` |
| For `linux_x64` the compiler uses the **dev** bundle, not the user one: `llvmHome.linux_x64 = $llvm.linux_x64.dev`, and that resolves to the distribution **`llvm-21-x86_64-linux-dev-116`** | same file, lines 431 and 785 |
| The host toolchain on this mac uses the **essentials** bundle instead (`llvmHome.macos_arm64 = $llvm.macos_arm64.user` → `llvm-21-aarch64-macos-essentials-97`) | same file, lines around 4 and 788 |

**Consequence 1 — the fork tag is `v2.4.20`, and it was not the obvious guess.** sborka's own
`gradle/libs.versions.toml` on `main` reads `kotlin = "2.4.10"`, because that is the version sborka
itself builds with. The number the subject compiles with is the one in the *published* catalog, and
they differ. A fork cut from the wrong tag would fail kill criterion 2 for a reason nobody would
look for.

**Consequence 2 — "the exact LLVM revision that Kotlin/Native release bundles" is not a revision
the brief can look up.** `konan.properties` names a JetBrains *distribution* — `llvm-21-x86_64-linux-dev-116`
— not an upstream commit. Which upstream LLVM 21 revision that build corresponds to, and whether
JetBrains carries patches on top of it, has to be read out of the fork's own build scripts. If it
carries patches, `opt` built from upstream LLVM 21 is not the same `opt`, and Route B's oracle
stops being an oracle. Addressed by [B-05](../backlog/B-05-six-unknowns-of-the-release-pipeline.md).

### 1.2 What the toolchain's LLVM bundle actually ships

| Fact | Where verified |
|---|---|
| The essentials bundle's `bin/` holds exactly nine entries: `clang`, `clang++`, `clang-21`, `clang-cache`, `ld.lld`, `lld`, `llvm-ar`, `llvm-cov`, **`llvm-profdata`** | `ls ~/.konan/dependencies/llvm-21-aarch64-macos-essentials-97/bin/`, reproduced 2026-09-20; independently recorded in `razves/docs/research/research-architecture.md` §1.1 |
| There is no `opt`, no `llvm-nm`, no `llvm-size`, no `llvm-objdump`, no `llvm-strip` in it | same listing |
| No `libclang_rt.profile*` anywhere in that bundle | `find` over the bundle, 2026-09-20 |
| `llvm-profdata` also exists in the 19 bundle and in the Android NDK toolchain under `~/.konan/dependencies` | same `find` |

**Consequence 1 — the brief's LLVM-tools row is half right, and the wrong half is the expensive
one.** "The Kotlin/Native toolchain ships almost no LLVM tools" is true of `opt`, which Route B
needs, and false of `llvm-profdata`, which the merge step needs. So the merge may cost nothing to
set up and the external `opt` is the whole of the tooling burden.

**Consequence 2 — and this was verified on the wrong bundle, deliberately stated.** The nine
entries are the **essentials** bundle on macOS aarch64. `linux_x64`, which is the study's only
target, gets `llvm-21-x86_64-linux-dev-116`, and a bundle called *dev* is entitled to hold more.
Listing it is hours of work and decides whether an LLVM build is needed at all, so it is the
cheapest item in the study and not an assumption: [B-05](../backlog/B-05-six-unknowns-of-the-release-pipeline.md).

**Consequence 3 — the profile runtime is a real cost either way.** `libclang_rt.profile` is absent
from the bundle that was listed, and the brief's two ways of writing a profile out of a service
that never reaches `atexit` both depend on it.

### 1.3 The macro unit, and the instrument that overstates it

Measured by the JIT phase on its own host (Ubuntu 24.04 in WSL2, 20 threads), 2026-09-11.

| Fact | Where verified |
|---|---|
| `µs CPU/request` is computed from `utime+stime` in `/proc/<pid>/stat` around a clean window, divided by responses | `zavarnik/docs/research/research-engines.md` §1.1 |
| The tick estimate **overstates by 6.4–7.2 % on that host, and overstates equally** at 25 context switches per second and at 298 000 — it is a kernel property, not a thread-count effect | same document §1.14, three variants against pinned-core occupancy from `/proc/stat` |
| On a kernel with `CONFIG_SCHEDSTATS=y` the same comparison showed **no bias at all** (ticks/exec 0.998–1.001 over six runs) | same section, the owner's spare 2-core box |
| The phase's written recommendation for future stands: take the cost per request from the occupancy of the **pinned cores**, which is bounded above by physics and converges with the truth at saturation | same section, "Следствие для чисел фазы" |

**Consequence.** The brief's Macro unit row specifies the instrument the phase it cites recommended
replacing. Ratios between arms are unaffected — the multiplier is common — but this study publishes
absolute µs per request, and "166 µs" on that host was really about 155. Amendment
[A1.1](../../BRIEF.md) records both numbers and makes core occupancy the unit of the verdict.

### 1.4 The two-host protocol belongs to xyk, not to the JIT phase

| Fact | Where verified |
|---|---|
| The JIT phase's article protocol said "JVM on cores 0–7, generator on 8–15"; in fact the subject and the generator shared all twenty cores in **every** configuration, including the one called pinned | `zavarnik/docs/research/research-engines.md` §1.1 |
| The cause: `taskset -pc <pid>` pins one thread, not the process — 49 of 50 threads still read `Cpus_allowed_list: 0-19` | same row |
| That phase decided not to re-measure, and its tables are true for what actually happened: one host, shared cores | same document, D3 |
| A genuine two-host protocol exists and was run on **xyk** on 2026-09-16: subject host a 4-core 7 GB cloud VM, generator host 4 cpu with k6 v1.4.1 on a private network about half a millisecond away, `constant-arrival-rate`, arms interleaved, three rounds, **round 1 discarded as warm-up, declared before the run** | `xyk/docs/research/measurements-2026-09-16/throughput-three-columns.md` |
| That protocol establishes **the generator's own ceiling** before reading an arm: the same pair offers 8 000 rps at p50 0.5 ms with zero dropped iterations and first strains at 16 000 | same document, and `measurements-2026-09-15/throughput-pilot.md` |
| It also closes the accounting: 60 000 offered, ≈13 100 delivered + 46 700 dropped = 59 800, so the generator is not losing anything quietly | same document |

**Consequence.** The brief's Hosts row cites the wrong phase, and the protocol it means is stricter
than the one it names. Pinned as xyk's ([A1.2](../../BRIEF.md)), which adds the generator-ceiling
check the JIT phase never had — the check that stops an arm being read off a saturated generator.

### 1.5 The ruler is this study's binding constraint, and no prior for it exists on this platform

| Fact | Where verified |
|---|---|
| On the JIT phase's host, within-variant spread over three interleaved runs was **±13 % for rps and 2–9 % for µs CPU/request** | `zavarnik/docs/research/research-engines.md` §1.5, D2 |
| On xyk's two-host pair, round-to-round spread of rps on a 30 s round was **1.05–1.07×** | `xyk/docs/research/measurements-2026-09-16/throughput-three-columns.md` |
| On a host showing the runtime four cores, with the generator pinned away, the Kotlin arm's own spread over four interleaved rounds was **2.3×**, against the Go twin's 1.02× on the same host and route | `xyk/docs/research/research-architecture.md` §1.18 |
| The subject host cannot have its clock fixed on the other portfolio Linux box either: no `intel_pstate` and no `cpufreq` under `/sys` in WSL2, turbo governed by the Windows host | `zavarnik/docs/research/research-optimizer.md` §1.4 |

**Consequence 1 — kill criterion 4 is the likeliest way this study ends, and it is also the
cheapest to reach.** The brief stops the macro half if the ruler is above 5 %. Every prior
measurement in the portfolio that resembles the ruler is at or above that: 2–9 % for the same unit
on a JVM, 5–7 % for rps on the very host pair this study will use, 130 % for rps on a four-core
host. The brief already runs the ruler first, in phase 0; this research says that ordering is not
a formality but the study's main risk, and the backlog puts it before the fork is even built.

**Consequence 2 — and the prior is only a prior.** Nobody in this portfolio has ever measured
`µs CPU/request` for a **Kotlin/Native** binary. The 2–9 % figure is a JVM's, on a different host,
with a different instrument bias. It sizes the risk; it does not predict the number, and the
results will say so next to whatever the ruler turns out to be.

**Consequence 3 — the macro threshold compounds it.** The brief's macro effect is "at least 5 %
*and* at least twice the ruler". At a ruler of 9 % the bar is 18 %, which is far above anything
instrumentation PGO returns on C and C++ servers. A ruler that merely fails to trip kill criterion
4 can still make RQ3 unanswerable, and the write-up has to say "below resolution, effect under
N %", never zero.

### 1.6 The ceiling prior — and why the JIT phase's "4 %" is not RQ1's number

The JIT phase measured, on konekt (a real JVM Ktor service, in-process profiler, categories by code
owner), that **user code owns 4.0 % of CPU and 3.4 % of allocations** at 50 rps. That number is
cited across the portfolio, and it is the wrong one to carry into RQ1.

| Fact | Where verified |
|---|---|
| Those shares are **user application code only**; the remainder at 50 rps was kotlinx 21.7 %, the Postgres driver 18.2 %, Ktor 13.0 %, stdlib 8.8 %, Exposed 4.7 % | `zavarnik/docs/research/research-optimizer.md` §1.8 |
| RQ1's Kotlin bucket is **application, libraries and stdlib alike** — the brief's own wording | [BRIEF.md](../../BRIEF.md), the attribution table |
| At 50 rps under a one-core limit that service was nearly idle: 2 817 CPU samples in 120 s, and 61 % of self samples were in "jvm" — JIT compiler threads among them | `zavarnik/docs/research/research-optimizer.md` §1.8 |

**Consequence 1 — the two bucket boundaries are not the same boundary, and the arithmetic does not
transfer.** Under RQ1's rule most of what the JIT phase called "libraries" would be Kotlin code; the
naive sum lands near half the profile rather than near four percent. That sum is **not** offered
here as a prediction: it is owner attribution on a JVM whose denominator includes JIT threads, and
RQ1 buckets self samples on a native binary with no JIT at all. What transfers is one warning —
**the portfolio's famous 4 % must not be quoted as RQ1's prior**, in either direction.

**Consequence 2 — there is no usable prior for RQ1, and that is why it is a two-day gate rather
than a paragraph.** The brief's 40 %/20 % thresholds rest on arithmetic over a 5–15 % PGO return,
not on any measurement of this platform. They stand as declared.

### 1.7 On this subject's host, the database is not the cost

| Fact | Where verified |
|---|---|
| `GET /health/live` — a route that parses nothing, verifies nothing and touches no database — delivered **434 rps** against the ingest route's **437**, on the same binary, host and generator | `xyk/docs/research/measurements-2026-09-16/throughput-three-columns.md` |
| The Go twin's ingest, doing the same signature check and the same SQLite insert, delivered **601** | same table |

**Consequence — and it is the reason this subject is a fair one for the question.** The brief
requires a subject with no co-located database taking a third of the machine; xyk goes further, in
that on this host the in-process database is not measurably the cost at all. Whatever RQ1's Kotlin
bucket turns out to be, it will not be an artefact of a database sitting in the profile. It also
means the cost lives in the HTTP and dispatch path — Kotlin code, the runtime and the kernel — which
is the territory PGO can in principle touch.

### 1.8 Four visible cores collapse this stack by two orders of magnitude

| Fact | Where verified |
|---|---|
| Same host, same binary, same route, four interleaved rounds: `--cpus=4` (a quota, 20 cores visible) gave a steady **3 871–3 954 rps**; `--cpuset-cpus=0-3` (4 cores visible) gave **355–816 rps** with the generator pinned away, spread 2.3× | `xyk/docs/research/research-architecture.md` §1.18 |
| Two visible cores were *better* than four: 1 353–1 670 rps, steady | same table |
| The Go twin on the same host and route: **55 953–56 972 rps**, spread 1.02× — flat across core counts | same table |
| The mechanism is **not established**, and the obvious suspect (a `SelectorManager` occupying a `Dispatchers.Default` worker) is contradicted by two cores being better than four | same section |
| An earlier, worse version of that table was the harness: the generator was free to run on the cores the subject was confined to. The catastrophic tail disappeared when they were pinned apart | the correction in the same section |

**Consequence 1 — the visible core count is part of the pin, not part of the host description.**
`nproc` as observed inside the subject, not the quota and not the node. The same binary with the
same four cores of CPU differs by up to ninety times depending on which of the two it was given.

**Consequence 2 — an unexplained 102× gap sits underneath every number this study will take.**
Whatever causes it is not machine-code quality, and if it is present at the stated offered rate it
will dominate RQ1's buckets and leave RQ3 no headroom. This is not a reason to stop; it is a reason
the ruler and the ceiling come before the compiler work, and a reason RQ1's bucket table is worth
having even if every later verdict is red — it is the first attribution anyone in this portfolio
will have taken of that gap.

**Consequence 3 — a rule that only lives in a script is a rule for the script.** xyk's harness
refuses same-host runs; the person driving it went around that a dozen times because each felt like
a quick diagnostic, and every one of those numbers had to be thrown away. Anything this study runs
by hand gets the same treatment, so the pinning belongs in whatever starts the subject.

### 1.9 The attribution grammar: twelve prefixes, and Rust that looks like the runtime

Measured by razves over two real Kotlin/Native binaries, one ELF and one Mach-O.

| Fact | Where verified |
|---|---|
| Kotlin/Native emits **twelve** `k…:` symbol prefixes; `kfun:`, `kclass:` and `kvar:` together are **12 125 of 23 336** Kotlin-prefixed symbols in the ELF binary | `razves/docs/research/research-architecture.md` §1.5 |
| The other nine — `kassociatedobjects:`, `kexttype:`, `kextoff:`, `kextname:`, `ktypew:` and the rest — are mostly vtables, interface tables and type info, and four of them appear only on Apple targets | same section |
| Mach-O symbols carry a leading underscore, so the prefix match must be `^_?k…` | same section |
| The Kotlin/Native C++ runtime is **Itanium-mangled (`_ZN…`) — and so is Rust**, because Rust's legacy mangling scheme produces `_ZN…` too | same document, §1.5 "Consequence 2" |
| Grouping `_ZN` as "the konan runtime" attributed about **964 kB** of `tokio`, `sqlx_postgres` and `core::ptr` to the Kotlin runtime in razves's own subject | same place |
| razves attributes bytes **and samples** to package and klib out of one symbol table, reading ELF and Mach-O itself with no subprocess, and charges every sample to exactly one row including the two rows for what it cannot name | `razves/README.md` |
| razves publishes an in-process sampler (`io.github.youndie.razves:sampler`) that a binary links and that samples itself | same file |

**Consequence 1 — the brief's Kotlin bucket names one prefix out of twelve.** Amendment
[A1.3](../../BRIEF.md) widens it to `^_?k[a-z]+:` and requires the twelve to be enumerated with
their sample counts *before* the gate is read, so that "the other eleven do not matter" becomes a
measured statement rather than a plausible one.

**Consequence 2 — the Runtime bucket cannot be drawn by mangling on this subject, and neither can
arm A3.** xyk's data layer is `sqlx4k`, which links Rust. Under the naive rule the Rust goes into
the Kotlin/Native runtime bucket, and A3 — "the profile applied to Kotlin code *and the runtime
bitcode*" — would be an arm nobody can describe. Amendment [A1.4](../../BRIEF.md) defines both by
owning object or klib, which razves already resolves.

**Correction, 2026-09-20, from [B-02](../backlog/B-02-can-the-subject-host-be-profiled.md): the
hazard is real but it is instrument-specific, and this section did not say which instrument.**
razves reads the symbol table itself, so it sees `_ZN…` and the warning applies to it in full.
`perf` **demangles Itanium symbols by default**, and on the subject host the Kotlin/Native runtime
came back already legible — `kotlin::alloc::CustomAllocator::CreateObject`,
`kotlin::gc::internal::MainGCThread<CmsGCTraits>::PerformFullGC`,
`kotlin::alloc::ObjectSweepTraits::trySweepElement`. Rust demangles to its own namespaces
(`tokio::`, `sqlx_postgres::`, `core::`), so in perf output the two **are** separable by name. Not
zero `_ZN` because there is no C++ — zero `_ZN` because perf had already unmangled it, which is
the kind of thing that reads as an absence if nobody checks.

A1.4 stands unchanged: defining the bucket by owning module is still correct, and it is now also
the only definition that gives razves and perf the same answer. What changes is the effort — on
perf output a namespace rule would mostly work, and "mostly" is what A1.4 exists to refuse.

**Consequence 3 — the kernel row is the one bucket razves cannot supply.** An in-process sampler
sees no kernel-mode samples. Either `perf` runs on the subject host or that row is reported as not
measured ([A1.5](../../BRIEF.md)), and on the portfolio's other Linux host `perf` is a stub not
built for the running kernel and `schedstat` is off entirely
(`zavarnik/docs/research/research-engines.md` §1.14). Checking the cloud host is hours of work and
is [B-02](../backlog/B-02-can-the-subject-host-be-profiled.md).

**Consequence 4 — razves output is data, not a verdict.** It is this portfolio's own tool measuring
this portfolio's own binaries. Its reconciliation identity and its unattributed and unparsed rows
are printed beside every table it produces, rather than folded away.

### 1.10 The subject's build options are part of the pin

| Fact | Where verified |
|---|---|
| xyk's release build has **four** measurement axes as Gradle properties, not two: `xyk.httpClient` (default `false`), `xyk.staticLink` (default `false`), `xyk.allocator` (default `paged-off`), `xyk.outbound` (default `real`) | `xyk/server/build.gradle.kts`, lines 28–44 |
| `paged-off` is `-Xbinary=pagedAllocator=false`; the other arms are `std` (the deprecated spelling of the same allocator), `fixed16` and `default` | same file, lines 139–162 |
| `xyk.httpClient=false` removes the outbound engine, and with it the delivery workers — the build xyk calls **ingest-only** | same file, and `xyk/docs/research/measurements-2026-09-16/throughput-three-columns.md` |
| The arm xyk's own two-host measurement was taken on was the ingest-only build, **statically linked** — which is not the build's default for either axis | `xyk/docs/research/measurements-2026-09-16/throughput-three-columns.md` |
| The choice was made on measurements recorded in that file — survival under a memory limit and rps, per allocator — and `-Xallocator=std` is deprecated with the compiler naming its replacement | same file, the comment block at lines 110–160 |
| RSS on Kotlin/Native follows thread count rather than live heap: the allocator holds a page per size class **per thread**, 256 kB by default | `zavarnik`-era measurement recorded in `kafka-native-spike/docs/research/research-architecture.md` §1.4 |

**Consequence 1.** The allocator moves the runtime's share of CPU, which is exactly RQ1's
denominator, and it moves binary size, which is RQ6's number. Every arm — A0 through A4 — carries
the same options, the results name them, and a verdict is stated for that configuration rather
than for "xyk".

**Consequence 2 — the pin follows the stand, not the build's defaults.** Two of the four defaults
differ from the arm xyk measured, and a pin taken from the defaults would mean none of §1.4's and
§1.5's priors — the generator ceiling, the round-to-round spread — describe the binary this study
runs. The pin is therefore `httpClient=false outbound=real staticLink=true allocator=paged-off`,
recorded in [BRIEF.md](../../BRIEF.md).

**Consequence 3 — and that pin excludes the delivery half of the product, which is a threat to
validity and not a detail.** Indirect call promotion is the mechanism the whole study rests on,
and the delivery path — workers, retries, per-attempt timeouts, timers — is where a service of
this shape keeps most of its polymorphic dispatch. Measuring ingest-only may therefore
**understate** what PGO is worth on this service. The reasons it is still the pin: the stand's
priors describe that binary, background delivery work would sit in one arm's profile and not
another's if any arm crashed a worker, and the shipping build carries a known outbound leak of
about 2 kB per request that drifts anything longer than a short round. **This is the one
judgement in the pins table that a reader may reasonably want reversed**, it is reversible until
the first measurement, and the write-up states the verdict as being about the ingest path.

---

## 2. Decisions

### D1. A separate repository, with the fork beside it *(2026-09-20)*

The study is a fork of a compiler, a patch set, a shell recipe and a document; none of that belongs
in the subject's repository, and the subject outlives the study. The shape is
`kafka-native-spike`'s, which answered a comparable question under a hard budget: a frozen
pre-registration, one research document that is amended rather than rewritten, one file per backlog
item, and raw logs that are the deliverable rather than an appendix.

Rejected: a third phase inside `zavarnik`, where the JIT phase lives. zavarnik is a published JVM
Gradle plugin with a badge and a release; a Kotlin/Native compiler fork inside it would make that
repository unreadable to anyone arriving at it for the plugin.

### D2. xyk is the macro subject *(owner's choice, 2026-09-20)*

It satisfies the brief's requirement — Kotlin/Native, Ktor, an in-process data layer, no co-located
database — and it brings the one thing the brief assumed existed and did not: a working two-host
stand with interleaving, a discarded warm-up round, an established generator ceiling and a culture
of criteria declared before the run (§1.4, §1.7). The candidates that also match on paper — keel,
metrik, tracy, katcher, shildik — would each start with building that stand.

Price of the choice, stated: xyk is the subject on which the four-visible-core collapse was found
(§1.8). Its stand is the best available *and* the one with a known unexplained pathology in it.

### D3. razves supplies the attribution; `perf` is asked only for the kernel row *(2026-09-20)*

RQ1's table is symbol-to-bucket attribution of samples, which razves already does at finer
granularity than the brief's five buckets, with the unnameable rows printed rather than dropped
(§1.9). The brief's `perf record -e cpu-clock` is kept for one reason only — kernel-mode samples —
and if it does not run on the subject host that row is declared missing rather than inferred.

Rejected: writing a sixth attribution script for this study. A second counter is how two checks in
one run come to report different numbers about the same file.

### D4. The ruler and the ceiling come before the fork is built *(2026-09-20)*

The brief already puts phase 1 (the ceiling) before phase 2 (feasibility), and says why: the
ceiling needs no compiler work and can make five days of RQ0 unnecessary. §1.5 adds a second
reason, and it is stronger: **the ruler can end the macro half on its own**, it costs a day, and
it needs neither the fork nor a profile. The backlog therefore opens with three items that touch no
compiler at all — the pins, whether the host can be profiled, and the ruler — and the fork is built
in parallel with them only because kill criterion 2 also has to clear.

### D5. Five amendments, made before the first measurement *(2026-09-20)*

[A1.1](../../BRIEF.md) through [A1.5](../../BRIEF.md): the macro unit's instrument, the
misattributed host protocol, the Kotlin bucket's prefix list, the Runtime bucket's definition (and
with it arm A3's), and the conditional kernel row. Each is motivated by a measurement recorded in
§1 above. **None of them moves a threshold**, and that is deliberate: the ruler's prior (§1.5) says
kill criterion 4 is the likeliest exit, and a threshold relaxed today because a prior says it will
be missed is the exact move the brief's own rule exists to forbid.

---

## 3. Hypotheses, each with an address

| # | Hypothesis | Checked by |
|---|---|---|
| H1 | The `linux_x64` **dev** bundle ships `opt` as well as `llvm-profdata`, and no LLVM build is needed | [B-05](../backlog/B-05-six-unknowns-of-the-release-pipeline.md) |
| H2 | JetBrains' LLVM 21 distribution carries patches over upstream, so an upstream-built `opt` is not the same `opt` | [B-05](../backlog/B-05-six-unknowns-of-the-release-pipeline.md) |
| H3 | `perf record -e cpu-clock` runs on the 4-core cloud subject host, unlike on the WSL box | [B-02](../backlog/B-02-can-the-subject-host-be-profiled.md) |
| H4 | The eleven Kotlin prefixes beyond `kfun:` carry under 1 % of self samples, so the brief's narrower rule would have given the same verdict | [B-06](../backlog/B-06-attribution-grammar-before-the-ceiling.md) |
| H5 | The ruler in µs CPU per request on this stand is at or above 5 %, tripping kill criterion 4 | [B-03](../backlog/B-03-the-ruler.md) |
| H6 | Two builds of the same source produce identical IR at the instrumentation point, so profiles survive a rebuild | [B-05](../backlog/B-05-six-unknowns-of-the-release-pipeline.md) |
| H7 | The unexplained four-visible-core collapse (§1.8) shows up in RQ1's buckets as kernel or runtime time, not as Kotlin code | [B-07](../backlog/B-07-rq1-the-ceiling.md) |

A hypothesis that turns out false is corrected **here, at the point of divergence**, with the
reason the first idea was wrong kept beside it — not deleted.

---

## 4. Risks, each with the machinery that mitigates it

**R1 — the ruler swallows the study.** Prior evidence puts it at or above the kill threshold
(§1.5). Mitigation is not hope: the ruler is measured first ([B-03](../backlog/B-03-the-ruler.md)),
with the *pinned-core* estimate rather than the biased process counter (A1.1), and if it is above
5 % the macro half stops while the micro half — RQ0, RQ2, RQ6 — still runs and still produces a
toolchain result. The brief's own kill criterion 4 says exactly this, and the backlog is ordered so
that reaching it costs one day rather than two weeks.

**R2 — the lever is never proved connected, and a null reads as a result.** Mitigation is the
brief's own rule, kept verbatim: every "nothing moved" states functions with the profile applied,
functions dropped on a CFG hash mismatch, and indirect call sites promoted, all read from **the
binary that was measured**, not a sibling build.

**R3 — the attribution silently mis-buckets and the gate moves with it.** Rust that mangles like
the runtime (§1.9) and eleven unclaimed Kotlin prefixes are both ways for RQ1 to return a confident
wrong number. Mitigation: the grammar is fixed and published as counts **before** RQ1 is read
([B-06](../backlog/B-06-attribution-grammar-before-the-ceiling.md)), and razves's unattributed and
unparsed rows are printed beside every table so that a bucket table that does not reconcile is
visible rather than tidy.

**R4 — a rebuild moves code, and code layout moves performance.** The brief's arm A4 exists for
this and is kept. Added from §1.8: the subject host's *visible core count* is recorded with every
run, because it moves the same number by up to ninety times and is not visible in the arm name.

**R5 — the generator is the thing being measured.** Mitigation is xyk's, not the brief's: the
generator's ceiling is established per endpoint before any arm is read, and the offered/delivered/
dropped accounting is required to close (§1.4). A run whose arithmetic does not close is discarded.

**R6 — the harness is bypassed for "a quick diagnostic".** This has already cost a dozen numbers in
this portfolio (§1.8). Mitigation: the pinning and the two-host refusal live in the thing that
starts the subject, and a measurement taken outside it is not admissible however convincing it
looks.

**R7 — instrumentation changes the program it profiles.** The brief's own threat, kept: if arm A1
cannot hold the training rate, the profile is taken at a lower rate and the results say so. Added:
the top indirect-call targets are compared across two training runs, because counters are racy
under threads and a target list that moves between runs invalidates RQ2's premise.

---

## 5. Code anchors

Research legitimately predates the code, and this study has none yet. What is cited here is other
repositories and the artefacts inside the toolchain; the notation with `!/` marks an address inside
something no tree here holds, and the checker reports those in their own section rather than as rot.

| Kind | Code |
|---|---|
| The macro subject | `xyk/server/build.gradle.kts` — the allocator and static-link options every arm carries |
| The macro subject's stand | `xyk/bench/run.sh`, `xyk/bench/columns.sh` — the two-host protocol and its refusal to take a same-host number |
| The prior phase | `zavarnik/docs/research/research-engines.md` — the macro unit, its bias, and the pinning defect |
| The prior phase | `zavarnik/docs/research/research-optimizer.md` — the ceiling measurement this study must not quote |
| The attribution tool | `razves/README.md` — bytes and samples per package and klib; the `:sampler` module |
| Compiler pins | `io.github.youndie.sborka:catalog:0.4.0.86!/catalog-0.4.0.86.toml` — Kotlin 2.4.20, Ktor 3.5.2, coroutines 1.11.0 |
| LLVM pins | `kotlin-native-prebuilt-macos-aarch64-2.4.20!/konan/konan.properties` — `llvmVersion.linux_x64=21`, `llvm-21-x86_64-linux-dev-116` |
| The fork | `JetBrains/kotlin@v2.4.20!/kotlin-native/backend.native/compiler/ir/backend.native/src/org/jetbrains/kotlin/backend/konan/llvm` — the pipeline Route A has to extend, named as the place to start reading and **not yet verified** to be the right directory |

---

## 6. What would end this study early, in the order it is likeliest

1. **The ruler above 5 %** (kill criterion 4, §1.5). One day of work, and every prior in the
   portfolio points at it. The micro half survives.
2. **RQ1 red** (kill criterion 3). Two days. RQ3 and RQ4 are not started; RQ0 and RQ2 may still run
   as a toolchain study making no performance claim, and the bucket table becomes the deliverable.
3. **The fork is not a valid baseline** (kill criterion 2). Two days. Nothing built from the fork
   can be compared with anything, and the study stops outright.
4. **RQ0 red** (kill criterion 1). Five days, and the most expensive of the four to reach, which is
   why it is fourth in the backlog rather than first.

The brief requires the stop to be written up with the same care as a result. In every one of these
four cases the write-up already exists in draft: this document, plus whichever items closed.
