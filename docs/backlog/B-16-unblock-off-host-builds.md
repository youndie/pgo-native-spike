---
id: B-16
title: "Unblock off-host builds: build xyk elsewhere, ship the binary to bench-a"
status: open
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
