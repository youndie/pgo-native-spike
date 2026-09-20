---
id: B-19
title: "Get the commit into the binary, and a GC-logging flag into xyk's build"
status: done
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

## Iteration 1 — 2026-09-20. Done, and the item was wrong about where half of it lived

**"Two one-line changes, both in xyk" was wrong on the first one.** The commit stamping is
**kore's** build-identity plugin, and that plugin **already takes a commit** for exactly this
case (kore #71: *"the commit, when the thing driving the build knows it and git does not"*). The
published `kore-build 0.1.4` that xyk already resolves carries `getCommit()` — checked by
disassembling the artifact out of the Gradle cache rather than by reading kore's `main`, because
merged is not released. **No library change was needed and none was made.**

That is the second time in this study a stated blocker cost nothing once it was looked at.

**xyk PR:** [youndie/xyk#8](https://github.com/youndie/xyk/pull/8) — opened for review, not
merged; it is a product repository and not this loop's to merge.

All three acceptance criteria were exercised on the real path (`logs/b-19/`):

- **AC 1.** `/version` on a binary built by rsync from a tree with `.git` excluded reports
  `commit: 6359a88a6467…`. The same service built the same way before the change reports
  `commit: unknown`, so the before-state is in the same log.
- **AC 2.** `bench/build-arm.sh gcinfo --extra-compiler-arg -Xruntime-logs=gc=info` produces a
  binary that logs `[INFO][gc][tid#…] Concurrent Mark & Sweep GC initialized` — **3 `[gc]` lines
  against the control's 0**, with both binaries started, exercised and stopped.
- **AC 3 (control).** With `.git` present and no environment variable, the plugin still asks git
  and reports the real HEAD with `dirty: true`. The git path is untouched.

**Four defects in `bench/build-arm.sh`, one of them its own documented invocation.** The header
claimed the commit was "passed in and asserted afterwards"; neither half was true. `-e
"${BUILDER#ssh }"` handed rsync the destination as its remote shell, so any `BUILDER` with an
option failed; `SOURCE_COMMIT` was written to a file nothing read; `--extra-compiler-arg` went to
`gradlew` verbatim, which is not a Gradle flag; and the scp fallback turned `-p 2222` into
"preserve timestamps". Plus `${arr[*]}` on an empty array, unbound under `set -u` in bash 3.2.

**And the new assertion caught itself before it caught anything else.** It reported `commit
compiled in: 0` against a binary whose generated source had the right commit: **Kotlin/Native
stores string literals as UTF-16**, and the check was grepping ASCII. As UTF-16LE the count is 1.
A false negative indistinguishable from the defect the check exists for — which is why the check
now names its encoding.
