---
id: B-04
title: "Build the fork at v2.4.20, and prove it is a valid baseline"
status: wip
priority: P0
size: L
stage: stage-0-stand
blocked_by: [B-01]
---

# B-04 — Build the fork at `v2.4.20`, and prove it is a valid baseline

Kill criterion 2: a binary from the unmodified fork must land within the ruler of a binary from the
stock distribution of the same release. If it does not within two working days, nothing built from
the fork can be compared with anything and the study stops outright. The threat is real and named
in the brief — a different host compiler, different flags or different LLVM build options shift the
baseline — and it is the criterion whose failure invalidates every later number rather than
answering a question.

- **The decision and its reason.** The tag is `v2.4.20`, not the version sborka builds itself with
  ([research §1.1](../research/research-architecture.md)). Kotlin/Native is built from that source
  on the Linux box; the mac is a draft editor with 16 GB and 41 GB of disk and will not hold a
  compiler build.
- The rejected alternative is a stock distribution with flags. The pipeline has to be changed, and
  a stock distribution cannot be — the brief's own reason, kept.
- Not covered: keeping the fork alive across Kotlin releases. The brief calls that a product
  decision, not a research result, and the fork tracks one tag and is not rebased.

- AC: `JetBrains/kotlin` at `v2.4.20` builds a Kotlin/Native that compiles the subject to a
  `linux_x64` release binary.
- AC: that binary and one from the stock 2.4.20 distribution are run through
  [B-03](B-03-the-ruler.md)'s protocol, interleaved, and the difference is **within the ruler**,
  with the ruler's own number printed beside it. "Within the ruler" is a comparison against a
  measured quantity, not a judgement.
- AC (positive control): the pair is also compared on something that must differ — binary size per
  owner with `razves`, or the compiler version string in the binary — so that a harness which
  compared a binary with itself by mistake is caught. Two builds that agree on everything are as
  likely to be one build measured twice.
- AC: the build is recorded as a script and a patch set, not as a shell history. The brief's
  deliverable is a recipe.
- AC: the effort is timed against the two-day criterion, from a recorded start.
- Anchors: `logs/b-04/`, `ci/fork/build-kotlin-native.sh`,
  `JetBrains/kotlin@v2.4.20!/kotlin-native/README.md`.

---

## Iteration 1 — 2026-09-20

**Two decisions taken without the owner, because the loop asked and got no answer in twenty
minutes. Both are reversible and both are stated rather than buried.**

### The build host is `bench-a`, not the WSL box

| | `bench-a` | the WSL box |
|---|---|---|
| cores | 4 | 20 |
| memory available | 5 of 7 GB | **3 of 15 GB** |
| disk free | 52 GB | 634 GB |
| load | ~0 | 2.0, with three Gradle daemons at ~2.7 GB each and one java at 100 % CPU |

The WSL box is five times the machine and is the portfolio's build host, and it is **not** used
here for two reasons. It has three gigabytes free against a compiler build that wants four to
eight, and this portfolio has already recorded what that produces — a load average of 118 and a
build failing on "Unable to connect to the child process". Making room would mean killing Gradle
daemons that, with a java process at 100 % CPU beside them, are plausibly **another session's
work**.

The positive reason matters more than the negative one. `bench-a` is where the existing xyk
binaries were built — `~/.konan`, `~/.gradle` and a checkout at `/root/soak/src/xyk` are all
there — so a fork-built compiler and the stock-built baseline it is compared against share a
glibc, a sysroot and a host. **Kill criterion 2 asks whether the fork is a valid baseline; a
toolchain built against a different glibc is a variable nobody wants inside that question.**

Cost, stated: four cores, so hours rather than minutes, and no measurement can run on the subject
host while it builds. Acceptable while B-04 is the only item in flight.

### The comparison uses eight counted rounds, not four

[B-03](B-03-the-ruler.md) left "adopt eight rounds?" as a question for the owner, because raising
the round count lowers RQ3's "twice the ruler" bar. **For this item the same change runs the other
way.** Kill criterion 2 asks that the fork's binary land *within* the ruler, so a tighter ruler
makes the test **harder** to pass: at four counted rounds a fork 4 % slower than stock would pass,
at eight rounds it would not. Adopting eight rounds here carries none of the concern that made it
a question there, and the two cases are not the same decision.

### Recorded

- The tag `v2.4.20` resolves to commit `890ac1d94fdb80eb85f0eeb5be5e4352df987b2f`, now pinned in
  [BRIEF.md](../../BRIEF.md) beside the tag, because a tag is a movable reference.
- **"Fork" is a local clone plus a patch set in this repository, not a GitHub fork.** The brief's
  deliverable is the patch set and the recipe; a fork on GitHub adds a place for work to live that
  is neither this repository nor upstream, and the non-goals rule out anything upstream anyway.
- `wsl-run` refuses this repository because it has no mutagen session, and it should not have one:
  the fork is upstream source cloned on the build host, never edited on the Mac.

### And then the host decision was wrong, for a reason neither table column covered

The clone failed in six milliseconds. **`bench-a` has no default route.** Its egress is a
deliberate allow-list — there is no `default` line in `ip route`, only specific host routes — and
the measurement host being locked down is sensible rather than broken.

| destination | |
|---|---|
| `github.com` :80 and :443 | **BLOCKED** |
| `cache-redirector.jetbrains.com` :443 | **BLOCKED** |
| `repo.maven.apache.org`, `download.jetbrains.com`, `services.gradle.org`, `plugins.gradle.org` | OK |
| `deb.debian.org` :80 | OK |

That is exactly the shape that lets xyk build there — Gradle resolves from Maven Central — and
stops a compiler being built there. **I checked cores, memory and disk before choosing the host
and did not check whether it could reach anything**, which is the part of "check the host before
the code" that a table of resources does not cover.

**Two blockers, not one**, and copying the source across ssh only removes the first:

1. `github.com` is unreachable, so the tree has to arrive another way.
2. `cache-redirector.jetbrains.com` is unreachable, and that is where Kotlin/Native fetches its
   toolchain dependencies. `bench-a`'s `~/.konan/dependencies` holds
   **`llvm-21-x86_64-linux-essentials-116`** and not the `dev` bundle — it has been *using* the
   prebuilt distribution (`kotlin-native-prebuilt-linux-x86_64-2.4.20`), never building one.
   `konan.properties` points `llvmHome.linux_x64` at `$llvm.linux_x64.dev`, so a compiler build
   needs a bundle this host cannot fetch.

**That second point is also half of [B-05](B-05-six-unknowns-of-the-release-pipeline.md)'s H1**,
found here rather than there: the `dev` bundle is a separate download from the `essentials` one a
user build needs, and it comes from the blocked host.

### The other candidate has not freed up

Re-checked at the end of this iteration: 3 of 15 GB available, load 1.6, three Gradle daemons
still resident, so nothing changed and the reason not to use it stands.

**Where this stopped.** No build host. The item needs one of: egress on `bench-a` for
`github.com` and `cache-redirector.jetbrains.com`; or the WSL box freed, which means establishing
that those daemons are nobody's and stopping them; or a third machine. **This is a question for
the owner and not a thing to decide by picking whichever failure is quieter** — the choice moves
which glibc the baseline is built against, which is the variable kill criterion 2 exists to hold
still.

Nothing was built. The clone is not on disk; `/root/kotlin-fork` was removed by the failed clone
and nothing else on either host was changed.
