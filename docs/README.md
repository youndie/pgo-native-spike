# Documentation map

This repository is a **research study under per-step budgets**, not a product, so the usual layer
cake is mostly absent: there are no features, no screens and no endpoints, because nothing is being
built here that a user reaches. What is being built is a fork, a patch set and a recipe — and,
more probably than not, a written account of why the question could not be answered on these
hosts.

| Document | What it is |
|---|---|
| [../BRIEF.md](../BRIEF.md) | The pre-registration: the pins, the five amendments made before the first measurement, and the brief as received. Frozen. |
| [research/research-architecture.md](research/research-architecture.md) | What was already measured elsewhere in the portfolio, what follows from it, every hypothesis with the item that checks it, and the four ways this study can end. **Start here.** |
| [../backlog.md](../backlog.md) | The work queue: the goal, the stages, the decisions, and the generated index. |
| [backlog/](backlog/) | One file per item. |
| [../logs/](../logs/) | Raw run logs, one directory per item. The findings are there; the prose is the index to them. |

## Coverage map

### Research (3)

- [2026-09-20-instrumentation-pgo](research/2026-09-20-instrumentation-pgo.md) — **the deliverable.** Verdicts per research question against the pre-registered thresholds, what was not measured and why, the claims withdrawn during the work, and where the CPU actually goes.
- [research-architecture](research/research-architecture.md) — the compiler and LLVM pins and how they were resolved, the macro unit and the instrument that overstates it, the ruler as the study's binding constraint, why the portfolio's ceiling number is not RQ1's prior, the attribution grammar, and the risks with the machinery that mitigates each.
- [source-brief](research/source-brief.md) — **the frozen text**, as it arrived on 2026-09-20 and byte for byte: the only copy in this repository, hashed by `make check` so that "unedited" is a claim the repository can support on its own. What the study *decided* is [BRIEF.md](../BRIEF.md); which of this brief's premises survived is the research and results documents.

The results document is **interim**: five of seven research questions have verdicts, and the
macro half is reported as not measured rather than estimated.
[B-13](backlog/B-13-publish-the-result.md) closes it when the study ends, whichever way that
happens.

