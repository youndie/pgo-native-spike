---
id: B-02
title: "Can the subject host be profiled at all — perf, or nothing"
status: open
priority: P0
size: XS
stage: stage-0-stand
---

# B-02 — Can the subject host be profiled at all: `perf`, or nothing

RQ1's instrument is `perf record -e cpu-clock` on an unstripped A0. On the portfolio's other Linux
box `perf` is a stub not built for the running kernel and `/proc/*/schedstat` returns zeros
because `CONFIG_SCHEDSTATS` is off ([research §1.9](../research/research-architecture.md),
consequence 3). Nobody has run `perf` on the cloud subject host. If it does not run there, RQ1 —
a two-day gate that can stop the study — has no kernel bucket, and the gate would be read off a
denominator nobody declared.

- **The decision and its reason.** Check the instrument before the item that depends on it, and
  check it on the host that will carry the measurement rather than on a machine that resembles it.
  This is hours of work and it changes what RQ1 can claim.
- The rejected alternative is discovering it inside [B-07](B-07-rq1-the-ceiling.md), where the
  cost is a day of a two-day budget and the temptation is to quietly drop the row.
- Not covered: the razves in-process sampler, which is
  [B-06](B-06-attribution-grammar-before-the-ceiling.md)'s business and cannot supply kernel
  samples whatever `perf` does.

- AC: on the subject host, `perf record -e cpu-clock` against a running unstripped Kotlin/Native
  binary produces a `perf.data` that `perf report` reads, with a non-zero count of kernel-mode
  samples — or it fails, and the exact failure is in the log.
- AC (positive control): the same command is run against a program known to spend its time in the
  kernel — a tight `read()` loop on `/dev/zero` — and the kernel bucket is visibly the majority.
  A profiler that resolves nothing produces the same empty kernel row as a program that never
  enters the kernel.
- AC: the resolved-symbol fraction is recorded. The brief discards a run above 5 % unresolved, and
  that rule needs a number from this host before RQ1, not after.
- AC: if `perf` does not run, amendment A1.5 takes effect verbatim — the kernel row is reported as
  not measured and RQ1's thresholds are applied to a stated user-mode denominator.
- Anchors: `logs/b-02/`, `xyk/bench/run.sh`.
