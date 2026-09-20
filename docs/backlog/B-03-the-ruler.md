---
id: B-03
title: "The ruler: A0 against itself, in µs CPU per request, on the two-host stand"
status: done
priority: P0
size: M
stage: stage-0-stand
blocked_by: [B-01]
---

# B-03 — The ruler: A0 against itself, in µs CPU per request

Before any arm is compared, the same binary runs against itself, interleaved, five rounds, and the
spread of that run is the ruler. Everything the brief calls an effect is defined relative to it,
and kill criterion 4 ends the macro half if it is above 5 %.

**This item is the study's main risk, and it costs one day.** Every prior in the portfolio that
resembles the ruler sits at or above the threshold: 2–9 % for the same unit on a JVM, 5–7 % for rps
on this very host pair, 130 % for rps on a four-core host
([research §1.5](../research/research-architecture.md)). No one has ever measured µs CPU per
request for a Kotlin/Native binary here, so the prior sizes the risk and predicts nothing.

- **The decision and its reason.** It runs before the fork is built and before any compiler work,
  because it needs neither and because it can end half the study on its own. The brief already
  orders the ceiling ahead of feasibility for the same kind of reason; this goes one step further
  ([research D4](../research/research-architecture.md)).
- **The unit is amendment A1.1's**: cost per request from the occupancy of the subject's pinned
  cores in `/proc/stat`, with `utime+stime` from `/proc/<pid>/stat` recorded beside it. The JIT
  phase measured the process counter overstating by 6.4–7.2 %, constantly, and wrote the
  replacement into its own research.
- The rejected alternative is rps. On this stack rps at small core counts is a sample rather than
  a property (spread 2.3×), and at high rates it measures the offered concurrency rather than the
  server.
- Not covered: any arm other than A0. Two binaries are not compared here; one binary is compared
  with itself.

- AC: five interleaved rounds of A0 against A0 at the stated offered rate per endpoint, round one
  discarded as warm-up, the within-arm spread printed per endpoint in both estimates.
- AC: the generator's own ceiling is established for each endpoint first — the offered rate at
  which dropped iterations appear — and the stated rate is below it, with the number in the log.
  xyk's stand already does this; the JIT phase's did not.
- AC: the offered / delivered / dropped accounting closes, as it did on xyk's pair. A run whose
  arithmetic does not close is discarded rather than explained.
- AC: `nproc` as observed inside the subject is recorded with every round. The same binary with the
  same four cores of CPU differs by up to ninety times depending on whether they arrive as a quota
  or a cpuset ([research §1.8](../research/research-architecture.md)).
- AC (positive control, and it is the one that makes the ruler a ruler): a deliberately different
  build — the same source with an obviously heavier flag, or the same binary under a second
  concurrent load — is run through the identical protocol and comes out **outside** the ruler. A
  ruler that cannot see a difference anybody can see is measuring the harness.
- AC: the verdict on kill criterion 4 is written the day this closes, whichever way it goes.
- Anchors: `logs/b-03/`, `xyk/bench/run.sh`, `xyk/bench/columns.sh`.

---

## Findings — 2026-09-20

**The ruler is a per-round paired difference with a standard deviation of 2.92 % of the mean.** At
the brief's five rounds (four counted) that is a 95 % interval of **±4.6 %** on a between-arm
difference. **Kill criterion 4 does not trip** — and the margin is one half of one percent, so the
sentence that matters is the next one.

**The macro half is not answerable at five rounds anyway.** The brief's macro effect is "at least
5 % *and* at least twice the ruler". Twice ±4.6 % is 9.3 %, which is far above anything
instrumentation PGO returns. At **eight** counted rounds per arm the ruler falls to ±2.44 % and
the binding constraint becomes the brief's own 5 % floor, which is what the brief intended. That
is fourteen minutes per comparison instead of seven.

| rounds per arm | 95 % CI on a between-arm difference | what then binds RQ3 |
|---:|---:|---|
| 4 (the brief's five, less warm-up) | ±4.64 % | twice the ruler: **9.3 %** |
| 8 | ±2.44 % | the brief's 5 % floor |
| 16 | ±1.55 % | the brief's 5 % floor |
| 25 | ±1.20 % | the brief's 5 % floor |

**Grand mean cost: 7 755 µs of CPU per request** — 1.54 of four cores at 200 rps, against a p50 of
5.4 ms. A 5 % effect is ~390 µs, which is a large absolute quantity; the difficulty is the
denominator's stability, not the size of what is being looked for.

### The estimator, and why the first answer was wrong

The brief says "the spread of that run is the ruler" and never defines spread. Three readings of
the same data differ by a factor of four, and the first write-up of this item used the wrong one.

**The paired difference within each round is the right estimator, and the argument is a priori
rather than chosen after seeing the numbers**: the arms are interleaved *because* a drift moves
both arms of a round together, and a paired difference is the standard estimator for that design.
The brief's own protocol agrees — it prints the within-arm spread *beside* the between-arm
difference, so the difference is what carries the verdict.

What made it vivid was the 120-second-settle run, which drifted **+441 µs per round, R² = 0.94**,
7 150 → 8 450 µs over four rounds. On that run the unpaired estimator reports ±13.0 % and the
paired one ±4.6 %; the drift is entirely absorbed by the interleaving it was designed for.

| run | gap between rounds | paired | unpaired |
|---|---|---:|---:|
| settle 120 s | 120 s, fixed | ±4.6 % | ±13.0 % |
| settle 20 s, working gate | ~24 s, fixed | ±5.5 % | ±4.2 % |
| gate timing out | ~140 s, fixed | ±3.9 % | ±3.2 % |
| load-average gate | 50–110 s, **variable** | ±5.6 % | ±6.3 % |

**Paired is stable at 3.9–5.6 % across all four; unpaired swings by a factor of four.** An earlier
note in this repository claimed "longer settling halves the spread" — that was the unpaired
estimator being fooled, and settle length in fact barely moves the paired number. Pooling all
sixteen paired differences gives sd 2.92 %, mean **+0.28 %** — unbiased, which is the check that
two copies of one binary really are one binary.

**The drift is unexplained and is not closed by this item.** It tracks wall time rather than round
count across runs, so the database growing by 6 000 rows a round is only one candidate and a
co-tenant on the cloud host is another. `/proc/stat` steal is not recorded separately, which is
what would tell them apart, and that is the first thing to add before RQ3.

### The positive control

Arm b under a two-core hog, three rounds:

| | clean arm a | hogged arm b |
|---|---:|---:|
| µs CPU/request (machine) | 7 832 | **17 113** |

**2.19×, and every hogged round is 107 % above the highest clean round** — outside the ruler under
any of the three readings. The stand can see a real difference.

**And the control found a defect in the unit A1.1 pinned.** The machine estimate charges every
process on the box to the arm being measured, so it reported 17 113 µs for a subject that was
using *less* CPU than usual: its own `utime+stime` fell to 5 671 µs under contention. The idle-arm
column added to catch exactly this **moved the wrong way** — the idle arm got less CPU, not more.
The guard that works is machine busy against the two arms' own CPU: **1.00 on every clean round,
2.59–2.88 on every hogged one.** It is now a column, and a row above 1.2 says `CONTAMINATED`
rather than leaving a plausible number to be read later.

### Also settled

- **The generator is not the ceiling.** Against the Go twin, which can absorb it, the pair
  delivered 1 997.7 rps of 2 000 offered with zero dropped and first strained at 8 000. At the
  ruler's 200 rps it runs at a few percent of that.
- **The subject's knee is between 300 and 400 rps.** 100, 200 and 300 come back exact with zero
  dropped and p50 5.3–6.7 ms; 400 delivers 345.9 with 671 dropped and p50 564 ms. The ruler is
  taken at 200, half the knee, because a ruler taken on a saturated subject measures the
  saturation.
- **Round 1 is not warm-up on this stand** — −0.7 % and +2.7 % against the counted means. The rule
  is kept because it costs nothing, not because it does anything.
- **The idle arm is never idle**: the second copy burns 1.8–2.8 % of the machine's busy time on
  timers and WAL work while serving nothing.
- **Provenance of the pinned arm is confirmed**: `xyk-pagedoff` has zero `curl_easy` symbols and
  `ldd` reports it is not a dynamic executable — the ingest-only, statically linked build the pin
  names. The allocator is taken from the filename and is consistent with the profile B-02 took
  (glibc malloc prominent, `CustomAllocator` present), not independently verified.

### Four harness defects, each of which passes or fails silently

Kept in the log rather than tidied away, because every one of them produced evidence
indistinguishable from a working run.

1. **The start step hung with no output** — backgrounded servers held the ssh session's stdin open.
   Reads as a slow host. `ssh -n` and `</dev/null`.
2. **`pkill -f ruler-hog` matched its own ssh command line** and killed the remote shell. In
   control mode that kills the cleanup rather than the load.
3. **The accounting check compared responses with iterations**, which reduces to `abs(x − x)`. It
   now compares against rate × duration, which is the only side that can disagree.
4. **The idle gate, twice.** Version one required the one-minute load average below 0.5 — a
   threshold a run leaving the box at 1.5 busy cores cannot reach, so it waited 150 s, timed out
   and proceeded through `|| true`. Version two summed `/proc/stat` by fixed field positions
   assuming eight numeric columns; Linux prints ten, so it reported "busy 9 cores" on a four-core
   box sixty times a round. **A four-core box claiming nine busy cores is the check saying it is
   broken**, and both versions then continued anyway.

And one the subject already had: the control run died on `EADDRINUSE` because `pkill` returns when
the signal is sent, not when the listener is gone. xyk's own B-20 recorded the same failure at six
times out of twelve. The start step now waits for the ports.

### Not covered

- **The fork.** This is the stock-distribution binary; A0 proper comes from the fork, and
  [B-04](B-04-fork-at-the-pinned-tag-and-the-baseline.md) has to show it lands inside this ruler
  before any of these numbers transfer.
- **The drift's cause**, above.
- **Whether eight rounds is adopted.** Raising the round count after seeing a number lowers the
  "twice the ruler" bar, which is the same shape as the two amendments
  [B-01](B-01-pins-and-the-amendment-window.md) had to tighten. The arithmetic is recorded; the
  decision is the owner's, and it is a `question` for them rather than a change made here.
