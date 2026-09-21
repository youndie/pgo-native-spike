# CLAUDE.md — pgo-native-spike

A research study under per-step budgets. One question: what LLVM instrumentation PGO is worth on a
Kotlin/Native service binary, built from a fork of the toolchain. **No library comes out of this
repository and nothing goes upstream** — the deliverables are a fork, a patch set, a recipe and a
document with its logs.

## Where to start a session

1. [docs/research/research-architecture.md](docs/research/research-architecture.md) — the evidence
   this study starts from. Without it the items look like "do the obvious thing", and the obvious
   thing is wrong in five places:
   - **The fork tag is `v2.4.20`, not `2.4.10`** (§1.1). sborka's own catalog on `main` says
     2.4.10 because that is what sborka builds *itself* with; the subject compiles with the
     version sborka *publishes*. A fork cut from the wrong tag fails kill criterion 2 for a reason
     nobody would look for.
   - **`llvm-profdata` is already in the toolchain; `opt` is not** (§1.2). The brief's "ships
     almost no LLVM tools" is half right, and the half that is wrong is the one that would have
     bought an unnecessary LLVM build. The listing was taken on the *essentials* bundle, and
     `linux_x64` gets the *dev* one — so the cheap item is to list it, not to assume either way.
   - **The macro unit's instrument overstates by 6–7 %** (§1.3), and the phase the brief cites
     wrote the replacement into its own research: read the cost per request off the pinned cores,
     not off `/proc/<pid>/stat`.
   - **The "two-host protocol of the JIT phase" is not the JIT phase's** (§1.4). That phase ran
     the subject and the generator on one box in every configuration, including the one it called
     pinned, and says so. The protocol the brief means is xyk's.
   - **`sqlx4k`'s Rust mangles like the Kotlin/Native runtime** (§1.9). Both are `_ZN…`, and the
     naive rule put ~964 kB of `tokio` and `sqlx_postgres` into the runtime bucket in razves's own
     subject. That boundary is also arm A3's definition.
2. [BRIEF.md](BRIEF.md) — the pre-registration. The pins table and amendments A1.1–A1.5 are the
   operative text where they differ from the brief as received.
3. [backlog.md](backlog.md) — the queue, the stages, the decisions.

## The rule that governs everything here

> **A threshold moves before the first measurement or it does not move.**

Five amendments were made on 2026-09-20 and **none of them moves a threshold**, deliberately: the
prior says kill criterion 4 is the likeliest exit, and a threshold relaxed today because a prior
says it will be missed is the exact move the rule exists to forbid. The window closes at the first
measurement. A number that comes in on the wrong side of a line after that is a result; if a
threshold turns out to have been badly chosen, that is a stated limitation in the write-up, beside
the number it affected.

## The second rule

> **A green without its positive control is not a green.**

A profiler that resolves nothing, a grammar that puts everything in one bucket, a protocol that
cannot see a difference anybody can see, a harness that never started — all four produce exactly
the evidence a pass produces. Every measuring item names a case that must come out a particular
way, and shows it doing so in the same log.

## What not to do

- **Do not quote "user code is 4 % of CPU" as RQ1's prior.** It is application code only, on a
  JVM; RQ1's Kotlin bucket is application, libraries and stdlib alike. The boundaries differ and
  the arithmetic does not transfer in either direction.
- **Do not report a number without the run that produced it.** Every figure in a document has a
  path into `logs/`. A retraction is appended; the original is not edited away.
- **Do not read rps as a verdict.** On this stack rps at small core counts is a sample rather than
  a property — the Kotlin arm's own spread on a four-core host was 2.3× — and at high rates it
  measures the offered concurrency. µs of CPU per request is the unit.
- **Do not take a number without `nproc` as observed inside the subject.** Four cores as a quota
  and four cores as a cpuset differ by up to ninety times on this stack, and neither is visible in
  the arm's name.
- **Do not take a measurement outside the harness.** xyk's harness refuses same-host runs, and a
  dozen numbers in this portfolio had to be thrown away because each bypass felt like a quick
  diagnostic.
- **Do not treat razves output as a verdict.** Print its reconciliation identity and its
  `unattributed` and `unparsed` rows rather than folding them away.
- **Do not report a difference under twice the ruler as zero.** It is "below resolution, effect
  under N %", with N stated.
- **Do not extend a budget.** A step that overruns is recorded as "not completed" with the reason,
  and the next step starts.
- **Do not let this become a library, a plugin or an upstream patch.** All three are the brief's
  non-goals. An item proposing one does not belong in the backlog.

## The loop merges its own pull requests

Stated by the owner on 2026-09-20. An iteration that closes an item opens its pull request **and
merges it** (squash, the item id in the footer, branch deleted), then moves on. Without this the
loop stalls: statuses on `main` only change when a pull request merges, so every item whose blocker
sat in an unmerged pull request would stay blocked on a blocker that still reads `open`, and every
later branch would conflict on `backlog.md` against a growing queue of them.

What does not change: `make check` is still green before the merge, an item is still `done` only if
its acceptance was **exercised** rather than implemented, and a `question` item still waits for a
person. A pull request opened by anything other than this loop — dependency bots included — is not
the loop's to merge.

**There is no CI to be green, and that is the uncomfortable half of this rule.** `make check` runs
on the machine doing the work, so the gate and the thing being gated share a host and an operator.
Until this repository is public and standard runners are free, the merge rests on a local run, and
the log of that run belongs in the pull request rather than in a sentence claiming it passed.

## Where the work runs

The fork build, the LLVM tools and anything `linuxX64` run on the WSL box through `wsl-run`. The
macro measurements run on xyk's pair — the subject host and the generator host — and never on the
machine that is compiling. **Edits are made in this checkout on the Mac**; the Linux side is a
replica, and work done there reaches neither git nor the Mac.

**A run log is captured on the Mac, never written on the box.** The raw logs are this study's
deliverable, so every measurement runs as `wsl-run '<script>' > logs/<item>/<date>.log`, with the
script printing everything to stdout and writing no files it wants to keep.

## Language

Everything in this repository is in English: documents, code, comments, commit messages, pull
request titles and bodies. Commits follow Conventional Commits.

## Checks

```bash
make check
```

Documentation and the readers' controls — there is no compiled artefact in this repository, and
[B-04](docs/backlog/B-04-fork-at-the-pinned-tag-and-the-baseline.md)'s fork was dropped once the
stock toolchain turned out to be enough. Whatever is not in `make check` is not a gate.

**CI is `.github/workflows/check.yml`, and it runs exactly `make check`.** It did not exist while this repository was
private: the account's Actions minutes are exhausted and a job on `ubuntu-latest` in a private repository
does not start at all, so a workflow would have sat in `queued` for ever — and a run that never
finishes looks exactly like a run that passed, which is worse than having none. **The repository
went public on 2026-09-21**, standard runners became free, and the workflow was added then, as
this paragraph always said it would be.

`make check` still runs locally before every push; CI is the second opinion, not the first.
