# pgo-native-spike

A research study, not a library. One question, asked against thresholds declared before any
measurement: **can LLVM instrumentation PGO be made to work on a Kotlin/Native service binary from
a fork of the toolchain, and how much request CPU does it remove?**

The case for it is one LLVM pass. Indirect call promotion records the top targets of every indirect
call and emits a guarded direct call the inliner can see through — speculative devirtualisation
without deoptimisation, which Kotlin/Native has no other source of. The case against is that PGO
improves machine code and nothing else: if a Kotlin/Native service spends its CPU in the allocator,
the collector and the kernel, the ceiling is low whatever the profile says.

**Nothing here goes upstream, nothing here becomes a library, and nothing here is packaged.** The
deliverables are a fork, a patch set, a shell recipe, and a verdict per research question with its
cost in microseconds of CPU per request — including the verdict that the question could not be
answered on these hosts, which is the likeliest single outcome.

## Where to read

| | |
|---|---|
| [BRIEF.md](BRIEF.md) | The pre-registration: pins, amendments, and the brief as received. Frozen. |
| [docs/research/research-architecture.md](docs/research/research-architecture.md) | What is already known, and what it implies about the order of the work. Start here. |
| [backlog.md](backlog.md) | The queue, the stages, and the decisions. |
| [docs/](docs/) | The documentation map. |

## Status

Nothing has been measured yet. Every number in this repository was taken on another subject,
another host or another platform, and is labelled as such.

## Checks

```bash
make check
```
