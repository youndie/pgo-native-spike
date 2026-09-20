# B-15 — razves's sampler cannot profile this subject, and the reason is not razves

The cross-check was not run, because **an in-process signal-based sampler kills this service**.
Everything up to that point works, and is recorded here so the next attempt starts from it.

## What was established before the wall

- **The reachability precondition was about the wrong host.** The AC required
  `reposilite.kotlin.website` over IPv6 "because that host has no IPv4 route". That is true of the
  **bench** hosts (B-04); builds run on the WSL box, which has IPv4 and reaches it with `200`.
  Third time in this study a stated blocker cost nothing once it was looked at.
- **`io.github.youndie.razves:sampler:0.1.0.33` resolves** — from reposilite's **snapshots**
  repository, which xyk's `settings.gradle.kts` already declares. It is on neither Central nor
  reposilite `releases`, and razves's README quotes `0.1.0.28`, which is not there either.
- **The sampler links and works on Kotlin/Native.** A 60 M-iteration arithmetic probe: 114
  samples, **0 dropped**, a dump razves read with **100 % of leaves named** and `BY ORIGIN` at
  `kotlin 100 %` — the right answer for a program that is nothing but arithmetic, so razves's side
  has its own positive control.
- **The patched subject builds**, at `-Pxyk.staticLink=true -Pxyk.allocator=paged-off` and the
  rest of the pin. **The sampler costs 22 160 bytes**: 20 191 608 against the pinned 20 169 448.
- The patch is `patches/razves-sampler.py` and applies to a **copy**. It is measurement
  scaffolding, so unlike B-19's two changes it is not proposed to xyk.

## The wall

```
Uncaught Kotlin exception: io.ktor.utils.io.errors.PosixException.InterruptedException:
    pselect failed, EINTR (4): Interrupted system call
  at kfun:io.ktor.utils.io.errors.PosixException.Companion#forErrno(...)
  at kfun:io.ktor.network.selector.SelectorHelper.$selectionLoopCOROUTINE$0.invokeSuspend
```

The sampler arms a POSIX timer and takes its samples in a signal handler. A signal delivered
while Ktor's CIO selector is blocked in `pselect` makes that call return `EINTR` — and **Ktor's
native selector loop does not retry on `EINTR`**; it converts errno to an exception, which is
uncaught, and the process dies.

**Same binary, same load, sampler the only difference:**

| arm | ingest rounds | survived | `EINTR` in log |
|---|---:|---|---:|
| sampler **off** | 1 089 | **yes** | 0 |
| 997 Hz | 1 153 | **no** | 1 |
| 97 Hz, 30 s | 1 026 | yes | 0 |

**And 97 Hz is not a safe rate — it just looked like one.** Three 60-second runs:

| round | ingest rounds | survived |
|---|---:|---|
| 1 | 2 168 | **no** |
| 2 | 1 943 | yes |
| 3 | 2 370 | **no** |

**Two deaths in three.** The single 30-second survival that suggested a lower rate might work was
one run of one variant, which is not a measurement — the study's own rule, applied to the study.

## Whose defect this is, and why it matters beyond here

**Not razves's.** A caller of `pselect` that does not handle `EINTR` is broken for *any* process
that receives signals — a profiler, a debugger, `SIGWINCH`, a timer somebody else armed. razves
makes it happen often enough to see; it does not cause it.

So the transferable statement is: **no in-process signal-based profiler can run against Ktor CIO
on Kotlin/Native** until that loop retries. `perf` is unaffected because it samples from outside
the process and delivers the target no signals — which is also why it remains the only instrument
that can answer RQ1 here.

## What this costs RQ1

Nothing that was published, and nothing is withdrawn. RQ1's numbers stand exactly as they were;
what is missing is the **second implementation** that would have checked them, so the caveat in
the results document — one sampler, one grammar, both written here — stays true and is now known
to be expensive to remove rather than merely not yet done.

Raw: `2026-09-21-sampler-eintr.log`.
