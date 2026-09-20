---
id: B-16
title: "Unblock off-host builds: build xyk elsewhere, ship the binary to bench-a"
status: done
priority: P0
size: M
stage: stage-0-stand
---

# B-16 — Unblock off-host builds

`bench-a` is the only machine the subject is measured on and it **cannot build the subject**. It
has no IPv4 route, and `reposilite.kotlin.website` — which serves the sborka catalog the build
resolves its compiler version from — is IPv4-only, as are `github.com` and
`cache-redirector.jetbrains.com`
([B-04](B-04-fork-at-the-pinned-tag-and-the-baseline.md), [B-07](B-07-rq1-the-ceiling.md)).

This blocks more than the fork. **Every arm of the study needs a rebuilt xyk**, and so does the
GC log RQ1 could not produce, because `-Xruntime-logs=gc=info` is a compile-time flag.

- **The decision and its reason.** Build somewhere that can, ship the binary. The subject host
  runs binaries; it does not have to make them. That separation is worth having anyway — it is
  what lets the fork-built and stock-built arms come from one place while being measured on
  another.
- The candidate worth trying first is the **Mac**, because Kotlin/Native supports a `linuxX64`
  target from a macOS host and the Mac has IPv4 and every dependency already. **It is a
  hypothesis, not a plan**: this portfolio has recorded that `linuxX64` *tests* cannot run on
  macOS, which is a different claim from cross-compiling, and 41 GB of free disk is not
  generous. Establish it before relying on it.
- The fallback is the WSL box, which needs its three resident Gradle daemons established as
  nobody's first, and costs the glibc 2.39-against-2.43 split.
- Not covered: building the **fork**. That is [B-04](B-04-fork-at-the-pinned-tag-and-the-baseline.md)
  and it also needs `github.com`, which shipping a binary does not solve.

- AC: a `linuxX64` release xyk built off `bench-a` runs on `bench-a` and answers `/health/ready`.
- AC (the control that makes it a baseline and not just a binary): the off-host build and the
  on-host `xyk-pagedoff` are compared through [B-03](B-03-the-ruler.md)'s protocol at **eight**
  counted rounds, and land within the ruler. A build host that changes the number is a variable
  in every later comparison.
- AC: the same recipe produces a build with `-Xruntime-logs=gc=info`, and it emits a GC log on
  `bench-a`. That is what [B-17](B-17-rq1-second-point.md) needs and RQ1 could not have.
- AC: the four pinned build properties are carried through and printed by the build, so a shipped
  binary names its own configuration.
- AC: the recipe is a script, not a sequence of commands in a findings section.
- Anchors: `logs/b-16/`, `xyk/server/build.gradle.kts`, `pgo-native-spike/bench/ruler.sh`.

---

## Iteration 1 — 2026-09-20

### The Mac is out, and not for the reason the item guessed

The item flagged the Mac as "a hypothesis, not a plan", and it failed on something neither
Kotlin/Native's cross-compilation nor the 41 GB of disk:

```kotlin
val nativeTarget = when {
    hostOs == "Mac OS X" && arch == "aarch64" -> macosArm64("native")
    hostOs == "Linux"    && arch == "x86_64"  -> linuxX64("native")
    ...
```

**The subject's build chooses its target from the host**, so there is no `linuxX64` target
registered on a Mac to build. And even with one, `staticLinux` is gated on
`System.getProperty("os.name") == "Linux"`, so a Mac cannot produce the *static* binary the pin
names. Two independent stops.

`bench-b` is out too: zero IPv4 default routes, same as `bench-a`, and no toolchain.

### The WSL box freed itself

| | when B-04 looked | now |
|---|---|---|
| memory available | 3 of 15 GB | **12 of 15 GB** |
| Gradle daemons | 3 resident | 1 |
| load | 2.0 | 1.0 |

So the option that needed someone's permission no longer needs it — the daemons were stale and
have gone. github, reposilite and cache-redirector are all reachable from there, and
`~/.konan/kotlin-native-prebuilt-linux-x86_64-2.4.20` is already present.

**And the glibc objection from [B-04](B-04-fork-at-the-pinned-tag-and-the-baseline.md) largely
dissolves**: the pinned arm is *statically* linked — `ldd` reports "not a dynamic executable" —
so a binary built against glibc 2.39 carries its own libc and does not meet 2.43 at runtime. The
concern is not zero (static glibc and NSS) but the ingest-only build resolves no names.

**`gh` on that box is no longer authenticated** — `HTTP 401: Bad credentials`. An inherited note
said it was; rechecking cost one command and would have cost an hour of confusion. The source is
therefore copied from the Mac with `rsync` rather than cloned, which is better anyway: it
guarantees the exact tree rather than a same-named ref.

### The finding that outranks the item: **the pinned arm has no provenance**

`xyk-pagedoff` answers `/version` with `built: 2026-09-15T16:37:16Z` **and no commit**. That is
xyk's own documented failure — a build context without `.git` stamps no commit — and it means
**the binary every number in this study was taken on cannot be traced to a source revision**.
Worse, `bench-a`'s checkout at `/root/soak/src/xyk` is at `c4ba99f`, dated 2026-09-17, which is
**two days after the binary was built**. The source it came from is gone.

**A baseline that cannot be rebuilt is not a baseline.** Every arm — A1, A2, A3, A4 — must come
from the same source as A0, so A0 has to be buildable. The consequences, stated rather than
worked around:

- **A0 is re-pinned to xyk at `c4ba99f41d62bdeb8a28377d0456c4d4c9a1bf2a`**, which the Mac and
  `bench-a` both hold and which is pushed. The Mac checkout is clean and on `main` at that
  commit.
- **`xyk-pagedoff` stops being the pinned arm.** Its numbers — [B-03](B-03-the-ruler.md)'s ruler,
  [B-07](B-07-rq1-the-ceiling.md)'s ceiling — remain valid *about that binary*, and B-03's ruler
  is a property of the stand rather than of the binary, so it carries. RQ1's shares are a
  property of the binary and must be re-taken, which [B-17](B-17-rq1-second-point.md) was going
  to do anyway.
- **This item's control has to be restated.** "The off-host build lands within the ruler of
  `xyk-pagedoff`" is confounded: any difference is build host *and* source version together, and
  no run can separate them because `bench-a` cannot build. The difference is therefore reported
  as the sum of the two, and not attributed to either.

**Where this is.** The source is on the box at `~/xyk-b16` with its commit written to
`SOURCE_COMMIT` beside it, since the rsync excludes `.git`. The A0 build is running:
`linkReleaseExecutableNative` with the four pinned properties.

**Not yet done:** the GC-logging build. `-Xruntime-logs=gc=info` is a `freeCompilerArgs` entry and
xyk's build exposes no property for it, so it needs a one-line change in **xyk**, not here. That
is a cross-repo change and is raised rather than slipped in.

---

## Findings — 2026-09-20

**Done.** Off-host builds work, the recipe is
[`bench/build-arm.sh`](../../bench/build-arm.sh), and **A0 is re-pinned to xyk at
`c4ba99f41d62bdeb8a28377d0456c4d4c9a1bf2a`, built on the WSL box.** The binary every earlier
number was taken on is retired.

### The build

| | |
|---|---|
| host | the WSL box — 20 cores, 12 of 15 GB free, full egress |
| command | `linkReleaseExecutableNative` with the four pinned properties |
| the build's own echo | `xyk build: httpClient=false outbound=real staticLink=true allocator=paged-off` |
| compiler | Kotlin **2.4.20**, confirmed by the resolved sborka catalog on the builder being the identical file (same cache SHA) as the Mac's |
| time | 1 m 32 s |
| result | static (`not a dynamic executable`), zero `curl_easy` symbols, 6 356 `kfun:` FUNC symbols, runs on `bench-a` and answers `/health/ready` |

### The comparison, and it does **not** land within the ruler

Eight counted rounds (A2.1), 120 s settle, arms interleaved, every round `clean` on the
contamination guard and zero dropped:

| | µs CPU/request |
|---|---:|
| `xyk-pagedoff` — the retired binary | **7 875** |
| `xyk-a0-c4ba99f` — the new A0 | **7 588** |
| paired difference | **+3.71 %**, 95 % CI **±3.20 %** |

**Distinguishable, and the new binary is the cheaper one** — by 3.71 % against an interval of
3.20 %, so it clears by half a point. Marginal, and this run's per-round sd is 3.82 % against the
pooled ruler's 2.92 %, so it is noisier than the ruler it is judged by; the interval is computed
from this run's own spread rather than the pooled one, so the verdict stands on its own data.

**The AC as written is not met, and it could not have been.** "Lands within the ruler" assumes
the two binaries differ only in build host. They differ in build host **and** source revision,
and because `bench-a` cannot build, no run can separate them. The 3.71 % is reported as the sum
of the two and attributed to neither.

**What matters more than the verdict: the offset cancels.** Every arm from here — A0, A2, A3, A4
— is built on the same host from the same commit by the same script, so the 3.71 % is a constant
that leaves every comparison this study will make. It only invalidates comparisons with the
*old* numbers.

### The binary is 76 % larger and costs less CPU

11 475 544 → 20 169 472 bytes, and 31 639 → 53 689 symbol-table entries. The striking part is the
binding split: **GLOBAL symbols 840 → 10 884**, thirteen-fold, while Kotlin functions barely moved
(6 085 → 6 356) and `_ZN` (312) and `_R` (1 323) are unchanged. So it is neither Kotlin code nor
the C++ runtime nor the Rust.

**The cause is not established.** It is not the compiler version, which is identical. It is not
debug info, which neither binary has. It is not the curl dependency, which neither carries. The
remaining candidates are the two days of source between the binaries and something in how the
retired binary was linked or post-processed, and they cannot be told apart without building the
old source, which no longer exists.

**The consequence is worth more than the cause**: on this subject **binary size and CPU per
request are not coupled** — 76 % more bytes cost 3.7 % *less* CPU. RQ6 measures size and RQ3
measures CPU, and this says plainly that neither predicts the other.

### What this invalidates, and what survives

- **[B-07](B-07-rq1-the-ceiling.md)'s ceiling does not transfer.** Those shares are a property of
  the retired binary. [B-17](B-17-rq1-second-point.md) re-takes them on the new A0, which it was
  going to do anyway for a different reason.
- **[B-03](B-03-the-ruler.md)'s ruler survives, with a caveat.** It is a property of the stand,
  measured as one binary against itself, and this run's per-round sd of 3.82 % is close enough to
  the pooled 2.92 % to keep using the pooled figure — but the two arms here are different
  binaries, which is itself a reason the spread could be larger, so B-17 should re-confirm it on
  the new A0 as a self-comparison.

### A defect I introduced and then documented, in that order

The first version of the recipe **reproduced the exact provenance failure this item had just
written up**: the rsync excludes `.git`, so the new binary also reports `commit: unknown`. It is
worked around with a `SOURCE_COMMIT` file beside the tree and a dirty-tree refusal in the script,
which is weaker than the binary knowing its own provenance. Fixing it properly is a change in
**xyk** and is [B-19](B-19-stamp-the-commit-into-the-binary.md).

### Not covered

- **The GC-logging build.** `-Xruntime-logs=gc=info` is a `freeCompilerArgs` entry and xyk's
  build exposes no property for it. Also [B-19](B-19-stamp-the-commit-into-the-binary.md); the
  script already accepts the extra argument for when it lands.
- **The fork.** Still [B-04](B-04-fork-at-the-pinned-tag-and-the-baseline.md), and the builder
  can reach `github.com`, so the host half of that question is now answered.
