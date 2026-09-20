---
id: B-16
title: "Unblock off-host builds: build xyk elsewhere, ship the binary to bench-a"
status: wip
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
