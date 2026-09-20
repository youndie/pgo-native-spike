---
id: B-17
title: "RQ1, second point: each endpoint at 50-70 % of its own saturation"
status: done
priority: P0
size: M
stage: stage-1-ceiling
blocked_by: [B-16]
---

# B-17 — RQ1's second point, at a rate chosen by rule

[B-07](B-07-rq1-the-ceiling.md) measured the ceiling at one rate per endpoint and found that the
rate changes the answer: `/journal` read **55.55 %** Kotlin saturated and **14.92 %** clean, a
factor of 3.7 on the gate's own quantity. The brief fixes a rate and never says how to choose it.
Amendment A2.2 now does, and this item takes the point it names.

The other end of the range is the reason a second point is needed rather than a re-run: **200 rps
on a four-core box is close to idle**, and a near-idle server spends its time being woken up. That
inflates the kernel bucket and deflates everything else, exactly as saturation inflates Kotlin.
The number that decides this study sits between the two ends, and neither existing point is it.

- **The decision and its reason.** 50–70 % of each endpoint's own saturation rate, established
  per endpoint rather than shared, because the endpoints' knees differ by an order of magnitude
  (ingest ~350 rps, `/journal` under 40).
- **The rule that decides Route A is declared in [BRIEF.md](../../BRIEF.md) A2.3 before this run**:
  if **Kotlin self plus runtime** stays under 40 % on every work endpoint, Route A, RQ5 and RQ6
  are dropped. On B-07's numbers, at the wrong rate, it would not fire — 40.69 %, 46.24 %,
  33.46 % — and that is recorded so the rule cannot read as having been chosen for its answer.
- The rejected alternative is averaging the saturated and idle points. They are not two samples
  of one quantity; they are two different regimes.
- Not covered: a verdict on RQ3. This sizes the ceiling, it does not measure an effect.

- AC: each endpoint's saturation rate is established first — the offered rate at which delivered
  falls below offered — and the run rate is 50–70 % of it, stated.
- AC: **every run is shown unsaturated**: delivered equals offered to within the generator's own
  error, and p50 is on the flat part of the curve. A run that is not is discarded, not adjusted.
- AC: one `--call-graph dwarf` capture per endpoint. B-07's inclusive column is a lower bound
  because 16.6–34.0 % of stacks had no callers — optimised Kotlin/Native omits frame pointers —
  and dwarf fixes it. File size is not a concern for a 30-second window.
- AC: the GC log from [B-16](B-16-unblock-off-host-builds.md)'s logging build, beside the buckets.
- AC: **Kotlin self plus runtime** is reported per endpoint as its own column, because that is the
  quantity A2.3's rule is written against.
- AC: the dwarf capture names **who calls libc malloc** — Ktor and kotlinx-io buffers, the
  runtime's C++ containers, SQLite, or the Rust. That is [B-18](B-18-allocator-probe.md)'s input
  and the study's most likely real finding.
- AC (positive control): the arithmetic control from B-07 is re-profiled through the dwarf
  pipeline and still reports above 80 % Kotlin. A change of capture mode is a change of
  instrument.
- Anchors: `logs/b-17/`, `pgo-native-spike/bench/ceiling.sh`, `pgo-native-spike/scripts/ceiling_report.py`.

---

## Findings — 2026-09-20

# The drop rule does **not** fire

**A2.3: Route A, RQ5 and RQ6 are dropped if Kotlin self plus runtime stays under 40 % on every
work endpoint.** It is 41.24 % on `/journal`, so the condition fails and **Route A survives** —
by 1.24 percentage points on one of three work endpoints.

That margin is small in absolute terms and is **not** noise: at 24 710 samples the binomial
interval on 41.24 % is ±0.61 %, so the true value is 40.6–41.9 % and is above 40 with confidence.
The call is close but it is clean.

| endpoint | rate | knee | Kotlin self | runtime | **self + runtime** | Kotlin anywhere | kernel | libc & native |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| `GET /health/live` | 960 | 1600 | 32.55 % | 17.83 % | 50.38 % | 57.20 % | 23.31 % | 25.69 % |
| `POST /hooks/{id}` | 180 | 300 | 21.22 % | 11.11 % | **32.33 %** | 37.15 % | 33.35 % | 31.00 % |
| `GET /api/events` | 120 | 200 | 16.40 % | 20.72 % | **37.13 %** | 28.30 % | 14.83 % | 45.91 % |
| `GET /journal` | 48 | ≥80 | 13.84 % | 27.40 % | **41.24 %** | 25.97 % | 13.86 % | 42.83 % |

Every run delivered its offered rate to five significant figures with sane p50s, so A2.2's
unsaturated requirement is met by measurement rather than by assertion. Zero unresolved samples.
Seed: 30 s of ingest at 200 rps, 4.1 MB of database. `nproc` 4.

**RQ1's own verdict is unchanged: still grey.** No endpoint reaches 40 % Kotlin *self*; the
highest is 32.55 % on the endpoint that does no work. The gradient B-07 found holds on the
re-pinned binary at rule-chosen rates — the more the endpoint does, the less of it is Kotlin.

Against B-07's numbers (retired binary, everything at 200 rps) the shares moved modestly:
ingest 33.46 → 32.33, apievents 40.69 → 37.13, journal 46.24 → 41.24, health 49.39 → 50.38. **The
rate rule did not rescue the study and did not sink it either**, which is the outcome that
justifies having fixed the rule before looking.

### Who calls libc malloc: the Kotlin/Native allocator itself

The question A2.5 posed, answered from the call graphs already captured rather than from the
dwarf capture that was supposed to answer it. **11.0–18.9 % of all samples have an allocator
function as their leaf** — on `/journal` that is larger than the entire Kotlin bucket.

| caller above the allocator | ingest | apievents | journal | health |
|---|---:|---:|---:|---:|
| `kotlin::alloc::CustomAllocator::CreateObject` | 3.70 % | 3.52 % | 4.50 % | 6.50 % |
| `kotlin::alloc::CustomAllocator::CreateArray` | 2.69 % | 5.93 % | 6.87 % | 4.40 % |
| `MainGCThread<CmsGCTraits>::PerformFullGC` | 0.71 % | 1.25 % | 1.63 % | 1.26 % |
| `sqlite3MemMalloc` | — | 2.50 % | 2.09 % | — |
| Rust (`CString::new`, `RawVecInner::finish_grow`) | — | 0.58 % | 0.46 % | — |
| `kfun:kotlinx.cinterop.ArenaBase#clearImpl` | 0.56 % | — | — | 1.35 % |

**It is not Ktor's buffers and it is not mostly SQLite. It is Kotlin/Native's own allocator
forwarding to system malloc** — which is what `pagedAllocator=false` means, and `paged-off` is
the setting the pin chose.

That sharpens [B-18](B-18-allocator-probe.md) considerably: a faster malloc sits directly under
the largest identified caller, and there is a second, cheaper probe the brief's non-goals do not
touch — **xyk already exposes the allocator as a build property**, so `fixed16` or `default` is an
arm rather than a preload. Both are recorded there.

### `--call-graph dwarf` does not work here, and the AC's remedy does not exist

The AC asked for a dwarf capture to fix B-07's truncated inclusive column. It produces **nothing**.

| | stacks | Kotlin frames | mean depth |
|---|---:|---:|---:|
| control, frame pointers | 11 990 | 11 990 | — |
| control, dwarf | **0** | 0 | — |
| subject, frame pointers | 24 710–71 766 | present | 9.9–19.7 |
| subject, dwarf | 506–2 870 | **0** | 8.7–9.4 (kernel only) |

On the subject dwarf returns kernel-only stacks; on the control it returns nothing at all. **Two
candidate mechanisms are ruled out**: `.eh_frame` is present and large (1.35 MB, 269 296 entries),
and this `perf` reports `dwarf-unwind: [ on ]` with libdw. A third — that my `dwarf,2048` stack
dump was too small, which would have been my parameter rather than a platform limit — was tested
across 2048, 4096, 8192 and 16384 and gives 0, 1, 0 and 2 stacks. **The cause is not
established**, and the consequence is that the inclusive column stays a lower bound taken from
the frame-pointer capture, where 21.9–33.6 % of stacks have no callers.

### The control

Frame-pointer capture on the arithmetic probe: **11 990 stacks, every one carrying a `kfun:`
frame**. The pipeline still reports a Kotlin-dominated workload as Kotlin-dominated at the rates
and captures used here.

**And it caught a false zero first.** The dwarf control initially reported "0 stacks" — because
an earlier cleanup had deleted the binary and there was no process to profile. An empty capture
and a missing subject are the same evidence, which is the third time that shape has appeared in
this study.

### Not covered

- **The GC log.** Still [B-19](B-19-stamp-the-commit-into-the-binary.md): `-Xruntime-logs=gc=info`
  needs a property xyk does not expose. The collector's *share* is measured here by symbol
  (`PerformFullGC` 0.71–1.63 % as an allocator caller, more as a leaf); its pause and sweep times
  are not.
- **`/journal`'s knee.** The ladder reached 80 rps without saturating and said so rather than
  returning its last rung as a knee. So `/journal`'s 48 rps is 60 % of a lower bound, not of the
  knee — the endpoint may tolerate more, and its share is the one the drop rule turned on.
  **This is the weakest number in the table and the one worth re-taking first.**
- **Re-confirming the ruler on the new A0.** [B-16](B-16-unblock-off-host-builds.md) flagged it;
  not done here.
