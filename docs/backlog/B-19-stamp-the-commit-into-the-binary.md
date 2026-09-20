---
id: B-19
title: "Get the commit into the binary, and a GC-logging flag into xyk's build"
status: open
priority: P1
size: XS
stage: stage-0-stand
---

# B-19 — Two one-line changes, both in **xyk** rather than here

Neither is this repository's code, which is why they are an item rather than a commit.

**1. `/version` reports `commit: unknown`.** The binary this study started on cannot be traced to
a source revision at all ([B-16](B-16-unblock-off-host-builds.md)), and the replacement has the
same defect for the same reason: the build reads the commit from `.git`, and any build from a
copied tree — a Docker context, an rsync, a release tarball — has none. `bench/build-arm.sh`
works around it by writing `SOURCE_COMMIT` beside the tree and printing the commit it used, which
is a weaker mechanism than the binary knowing its own provenance.

**2. `-Xruntime-logs=gc=info` cannot be turned on from outside.** It is a `freeCompilerArgs`
entry and xyk's build exposes no property for it, so the GC picture RQ1 was supposed to carry
could not be produced. [B-17](B-17-rq1-second-point.md) needs it.

- **The decision and its reason.** Both are changes to a product repository made for a study's
  convenience, so they are proposed rather than pushed: a property that lets the commit be passed
  in when `.git` is absent, and a property that appends compiler arguments. Each is small and each
  is useful to xyk independently of this study — the first is a real defect in its release
  stamping, and the second is what lets anyone profile its collector.
- The rejected alternative is patching xyk in a branch this study owns. Two forks of a product
  repository, one of which nobody is watching, is worse than an unanswered question.
- Not covered: anything else in xyk.

- AC: a binary built from a tree without `.git` reports the right commit at `/version`.
- AC: the GC-logging build is produced by `bench/build-arm.sh` with no local patch.
- AC (control): a binary built the ordinary way, from a checkout with `.git`, still reports the
  commit it used to — the change adds a path, it does not replace one.
- Anchors: `xyk/server/build.gradle.kts`, `pgo-native-spike/bench/build-arm.sh`.
