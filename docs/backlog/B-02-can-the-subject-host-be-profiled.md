---
id: B-02
title: "Can the subject host be profiled at all — perf, or nothing"
status: done
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

---

## Findings — 2026-09-20

**Green. `perf` works on `bench-a`, kernel samples included, and amendment A1.5 does not take
effect.** RQ1 keeps its kernel bucket, so it can be reported green if it earns it.

Logs: `logs/b-02/`.

### The host

| | |
|---|---|
| `perf` | `perf version 7.0.14`, kernel `7.0.0-30-generic` — matched, not the stub the WSL box has |
| `perf_event_paranoid` | `-1` (everything permitted) |
| `kptr_restrict` | `1`, and the session is uid 0, so `/proc/kallsyms` returns real addresses |
| cores | 4 |

### AC2 — the positive control, run before anything was believed

| Workload | `[kernel.kallsyms]` self | user-side self |
|---|---|---|
| `dd if=/dev/zero of=/dev/null bs=4k` | **51.70 %** | libc 44.44 %, `dd` 3.84 % |
| `awk` arithmetic loop | ~0 % | `gawk` 99.96 % |

The instrument separates the two, so a kernel row that comes back small later is a fact about the
workload rather than about the profiler. `cpu-clock:k` and `cpu-clock:u` were also recorded
separately and both returned non-zero samples, which is the same claim without relying on DSO
names.

**A misread, recorded because it is the failure this item is for.** The first control was taken
with `-g` and read through `--sort=dso`, which showed `dd 99.95 %` and raw addresses — and was
briefly taken for "no kernel samples". It was the call-graph report attributing *children* to the
root frame. The evidence for "the profiler cannot see the kernel" and for "I am reading the wrong
column" is identical until you look at the second column.

### AC1 — the real subject, and a second failure worth keeping

`/root/xyk-pagedoff` under a local request loop, 20 s, `-F 999`, 6 871 samples, 19 threads.

| Bucket | Leaf frames | Share |
|---|---|---|
| `[kernel.kallsyms]` | 2 392 | **34.8 %** |
| `kfun:` | 1 468 | 21.4 % |
| `kotlin::` (the C++ runtime, demangled) | 513 | 7.5 % |
| `[vdso]` | 62 | 0.9 % |
| `[unknown]` | 0 | **0 %** |

**The first attempt profiled the wrong process.** `pgrep -f xyk-pagedoff | head -1` returned the
wrapper, not the server — 1282808 against 1282811 — and produced a 29 kB `perf.data` with one
thread and an empty report. A profiler pointed at the wrong subject returns exactly what a subject
with nothing to sample returns. The pid is now taken from `ss -lptn 'sport = :8099'`, which is the
process holding the port by construction.

### AC3 — the unresolved fraction

**0 % on the subject**, 3 % on the `dd` control. The brief discards a run above 5 %; this host is
not near it.

### Three things found on the way, each handed on rather than acted on

1. **`perf` demangles Itanium symbols, so the Kotlin/Native runtime arrives legible** as
   `kotlin::alloc::CustomAllocator::CreateObject` and
   `kotlin::gc::internal::MainGCThread<CmsGCTraits>::PerformFullGC`. The `_ZN` count was zero, and
   that is demangling rather than an absence of C++. Research §1.9 said the runtime cannot be told
   from `sqlx4k`'s Rust by mangling; that is true of razves, which reads the symbol table itself,
   and not of perf. Corrected there, at the point of divergence.
2. **The binary is statically linked** — `ldd` says "not a dynamic executable" — so glibc lives
   inside it and perf charges `__libc_calloc`, `_int_malloc`, `malloc_consolidate` and friends to
   the `xyk-pagedoff` DSO. **The brief's "libc and other native" bucket therefore cannot be drawn
   by DSO on this subject**, which is another reason A1.4's owning-module rule is the right one.
   For [B-06](B-06-attribution-grammar-before-the-ceiling.md).
3. **H4 is untouched, not confirmed.** The 513 non-`kfun:` frames that a first pass counted as
   "other Kotlin prefixes" were C++ namespaces, not symbol prefixes. Nothing here says anything
   about the eleven prefixes beyond `kfun:`; that enumeration is still
   [B-06](B-06-attribution-grammar-before-the-ceiling.md)'s.

### What this is **not**

**The `kfun:` share of 21.4 % is not RQ1's answer and must not be quoted as one.** It sits
suggestively between the brief's 20 % red and 40 % green, and every condition around it is wrong
for that question: the generator was a `curl` loop **on the subject host**, which is the one thing
xyk's harness exists to refuse; the rate was whatever that loop produced rather than the stated
offered rate; it is one 20-second window rather than five interleaved rounds; the binary's
provenance is unverified, so it may not even be the pinned arm; and the attribution grammar it
would be read through is not fixed until
[B-06](B-06-attribution-grammar-before-the-ceiling.md). It is recorded because deleting it would
be worse, and fenced because a number of the right shape in the right range is exactly what gets
quoted later without its conditions.

### Not covered

**The real subject runs in a container** — `xyk/bench/run.sh` starts it with
`docker run --cpuset-cpus=0-3` — and this item profiled a bare process. No xyk image is on the
host any more, so whether perf resolves symbols for a containerised process from the host side is
untested. It is a real question for [B-07](B-07-rq1-the-ceiling.md) and is named in its findings
when that item runs, not assumed away here.
