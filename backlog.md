# Backlog: what instrumentation PGO is worth on a Kotlin/Native service

> Role of this document: the study's work queue. **One file per item in
> [`docs/backlog/`](docs/backlog/)** — `B-NN-<slug>.md`. What lives here is the index (generated)
> and everything that is not an item: the goal, the stages, and the decisions.
>
> New item: copy [`docs/templates/backlog-item.md`](docs/templates/backlog-item.md), take the next
> free `B-NN`, and run `python3 scripts/backlog_index.py` after editing.

## Goal

Answer the brief's question — can LLVM instrumentation PGO be made to work on a Kotlin/Native
service binary from a fork of the toolchain, and how much request CPU does it remove — and publish
the answer whatever it turns out to be. The pre-registration is [BRIEF.md](BRIEF.md); the evidence
that shaped the order, the pins and the five amendments is
[docs/research/research-architecture.md](docs/research/research-architecture.md).

This backlog is finished when [B-13](docs/backlog/B-13-publish-the-result.md) closes — including
when the study is killed, because the brief requires a stop to be written up with the same care as
a result.

Nothing here goes upstream, and nothing here becomes a plugin. Both are the brief's non-goals, and
an item proposing either does not belong in this file.

## Stages

| Stage id | Stage | What it is |
|---|---|---|
| `stage-0-stand` | The stand, before any compiler work | The pins, the instrument, the ruler, and whether the fork is a valid baseline. Two kill criteria live here and neither needs a profile. |
| `stage-1-ceiling` | The ceiling | RQ1, plus the attribution grammar it is read through. Kill criterion 3. |
| `stage-2-feasibility` | Feasibility | RQ0. The longest budget in the study, taken third on purpose. Kill criterion 1. |
| `stage-3-mechanism` | The mechanism, priced | RQ2 and its two controls of known outcome. Kill criterion 6. |
| `stage-4-macro` | The question itself | RQ3 and RQ4 on the service. Kill criterion 5. |
| `stage-5-cost` | What it costs to keep | RQ5 and RQ6. |
| `stage-6-publish` | The deliverable | The verdict table, the recipe, the patch set, and what was not measured. |

## Marks

`[ ]` open · `[~]` in progress · `[x]` done · `[?]` open question · `[-]` dropped

<!-- BEGIN INDEX -->

## Open (11)

| Task | | Priority | Size | Blocked by |
|---|---|---|---|---|
| [B-04](docs/backlog/B-04-fork-at-the-pinned-tag-and-the-baseline.md) `[?]` | Build the fork at v2.4.20, and prove it is a valid baseline | P0 | L | B-01 |
| [B-06](docs/backlog/B-06-attribution-grammar-before-the-ceiling.md) `[ ]` | Fix the attribution grammar, with counts, before the ceiling is read | P0 | S | B-02 |
| [B-07](docs/backlog/B-07-rq1-the-ceiling.md) `[ ]` | RQ1 — the ceiling: what share of self CPU is Kotlin code | P0 | M | B-03, B-06 |
| [B-08](docs/backlog/B-08-rq0-a-merged-profile-applied.md) `[ ]` | RQ0 — a profile that merges and applies, by Route B then Route A | P0 | XL | B-05 |
| [B-09](docs/backlog/B-09-rq2-indirect-call-promotion.md) `[ ]` | RQ2 — does indirect call promotion fire on Kotlin dispatch, and what is it worth | P0 | M | B-08 |
| [B-10](docs/backlog/B-10-rq3-rq4-the-macro-arms.md) `[ ]` | RQ3 and RQ4 — arms A0, A2, A3 and A4 on the service | P0 | L | B-07, B-08 |
| [B-13](docs/backlog/B-13-publish-the-result.md) `[ ]` | Publish the result, including the parts that were not measured | P0 | M | B-07, B-09, B-10, B-12 |
| [B-05](docs/backlog/B-05-six-unknowns-of-the-release-pipeline.md) `[ ]` | Answer the six believed-and-unchecked items against the fork's source | P1 | M | B-04 |
| [B-11](docs/backlog/B-11-rq5-how-long-a-profile-lives.md) `[ ]` | RQ5 — how long a profile lives | P1 | M | B-10 |
| [B-12](docs/backlog/B-12-rq6-what-it-costs.md) `[ ]` | RQ6 — what it costs: binary size per owner, build time, A1's overhead | P2 | S | B-08 |
| [B-14](docs/backlog/B-14-make-the-freeze-checkable-from-the-repo.md) `[ ]` | Make BRIEF.md's freeze checkable from the repository alone | P2 | XS | - |

## Closed (3)

**The stand, before any compiler work**

- [B-01](docs/backlog/B-01-pins-and-the-amendment-window.md) `[x]` - Pin every row of the fixed setup, and close the amendment window
- [B-02](docs/backlog/B-02-can-the-subject-host-be-profiled.md) `[x]` - Can the subject host be profiled at all — perf, or nothing
- [B-03](docs/backlog/B-03-the-ruler.md) `[x]` - The ruler: A0 against itself, in µs CPU per request, on the two-host stand

<!-- END INDEX -->

## Decisions worth not re-litigating

**The ruler comes before the fork, not after it.** The brief already puts the ceiling ahead of
feasibility and says why — the ceiling needs no compiler work and can make five days of RQ0
unnecessary. Research adds a stronger reason: the ruler can end the macro half on its own, it
costs a day, and every prior in the portfolio that resembles it sits at or above the 5 % kill
threshold — 2–9 % for the same unit on a JVM, 5–7 % for rps on this very host pair, 130 % for rps
on a four-core host. So [B-03](docs/backlog/B-03-the-ruler.md) runs first among the measuring
items, and [B-04](docs/backlog/B-04-fork-at-the-pinned-tag-and-the-baseline.md) builds the fork
beside it only because kill criterion 2 also has to clear.

**The pins were resolved, and three of the four were not the obvious reading.** The fork tag is
`v2.4.20` — the version the subject's *published* catalog carries, not the `2.4.10` that sborka
builds itself with. The LLVM row names a JetBrains distribution, not an upstream revision. The
subject is xyk. The "two-host protocol of the JIT phase" is xyk's protocol; the JIT phase's own
research records that it ran the subject and the generator on one box in every configuration,
including the one it called pinned.

**Five amendments were made before the first measurement, and none of them moves a threshold.**
A1.1 the macro unit's instrument, A1.2 the host protocol, A1.3 the Kotlin bucket's prefix list,
A1.4 the runtime bucket's definition and with it arm A3's, A1.5 the conditional kernel row. Each
is motivated by a measurement recorded in the research. The window closes at the first measurement
of this study. A number that comes in on the wrong side of a line after that is a result, not a
reason to redraw the line.

**The attribution grammar is published as counts before the gate is read.** RQ1 is a gate whose
whole content is a bucket table, and the brief's rules are wrong twice on this subject: `kfun:` is
one Kotlin prefix of twelve, and the runtime cannot be told from `sqlx4k`'s Rust by mangling,
because both are `_ZN…`. Fixing the grammar after seeing which side of 40 % the number fell on
would make the gate meaningless, so [B-06](docs/backlog/B-06-attribution-grammar-before-the-ceiling.md)
closes before [B-07](docs/backlog/B-07-rq1-the-ceiling.md) opens.

**The portfolio's "user code is 4 % of CPU" is not RQ1's prior and is not quoted as one.** That
number is application code only, on a JVM; RQ1's Kotlin bucket is application, libraries and
stdlib alike. The two boundaries are not the same boundary, and the arithmetic does not transfer
in either direction.

**Every measuring item carries a positive control.** A harness that never started, a profiler that
resolves nothing, a grammar that puts everything in one bucket and a protocol that cannot see any
difference all produce exactly the evidence a pass produces. Where the control is not obvious it is
written as an acceptance criterion, and a green without its control is not a green.

**razves output is data, not a verdict.** It is this portfolio's own tool measuring this
portfolio's own binaries. Its reconciliation identity and its `unattributed` and `unparsed` rows
are printed beside every table it produces.

**A dropped item is kept, not deleted.** If a kill criterion closes a stage, its items become
`dropped` with the reason in the file and the condition that would re-open them. The negative
result is a deliverable of this study, and an item that vanished records nothing.
