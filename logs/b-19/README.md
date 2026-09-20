# B-19 — the commit stamp and the GC-logging flag

## The item's premise was half wrong, and that halved the work

B-19 says "two one-line changes, both in **xyk**". The commit half is not xyk's code at all: the
stamping comes from **kore's** build-identity plugin, and **that plugin already takes a commit**
for exactly this case (kore #71 — *"the commit, when the thing driving the build knows it and git
does not"*). The published `kore-build 0.1.4` that xyk already resolves carries `getCommit()`,
confirmed by disassembling the artifact out of the Gradle cache.

So no library change was needed and none was made. What was missing was the **wiring**, in xyk,
and the caller, here.

## What was verified, and how

| | |
|---|---|
| AC 1 — a binary built from a tree without `.git` reports the right commit at `/version` | **met** |
| AC 2 — the GC-logging build is produced by `bench/build-arm.sh` with no local patch | **met** |
| AC 3 (control) — an ordinary build from a checkout with `.git` still reports the commit it used to | **met** |

**The before and after are the same service on the same host**, both built by rsync from a tree
with `.git` excluded:

    xyk-a0-c4ba99f  (before)  /version -> release: 0.1.0+unknown   commit: unknown
    xyk-gcinfo-6359a88 (after) /version -> release: 0.1.0+6359a88a6467...
                                           commit: 6359a88a64677f1c9b74c130fcc75dbbc82fbfef

**Five cases of the commit path**, run against the identity task directly:

| | commit reported |
|---|---|
| no `.git`, no environment | `unknown` — the defect, reproduced |
| `SOURCE_COMMIT=deadbeefcafe` | `deadbeefcafe` |
| `GITHUB_SHA=0123456789ab` only | `0123456789ab` — the fallback |
| both set | `SOURCE_COMMIT` wins |
| `SOURCE_COMMIT=` (empty) | `unknown`, not an empty string |
| **`.git` present, no environment** | **the real HEAD, `dirty: true`** — the git path is untouched |

**The GC flag, with its negative control** — both binaries started, exercised and stopped:

    xyk-gcinfo (flag on)   3 lines matching [gc], of 24 logged
    xyk-a0     (flag off)  0 lines matching [gc], of 13 logged

    [INFO][gc][tid#1317088][0.000s] Adaptive GC scheduler initialized
    [INFO][gc][tid#1317088][0.000s] Concurrent Mark & Sweep GC initialized

## Four defects in `bench/build-arm.sh`, and the documented invocation was one of them

The script's own header claimed the commit was "passed in and asserted afterwards". Neither half
was true, and the invocation printed in its usage line had never run.

1. **`-e "${BUILDER#ssh }"`** handed rsync `-p 2222 youndie@127.0.0.1` as the remote shell —
   `exec on '-p': No such file or directory`. Any `BUILDER` carrying an option hit it.
2. **`SOURCE_COMMIT` was written to a file nothing reads.** xyk's build takes it from the
   environment; the file stays because it is what says which revision the build tree is.
3. **`--extra-compiler-arg` was passed to `gradlew` verbatim**, which is not a Gradle flag. It is
   now translated to `-Pxyk.extraCompilerArgs`, the property this item added to xyk.
4. **The scp fallback translated `ssh` to `scp` textually**, so `-p 2222` would have meant
   "preserve timestamps" rather than a port. The binary is fetched over `BUILDER` itself now.

Plus `${arr[*]}` on an empty array, which is unbound under `set -u` in the bash this mac ships.

## And the assertion caught itself first

The new check reported **`commit compiled in (want 1): 0`** against a binary whose generated
source carried the right commit. **Kotlin/Native stores string literals as UTF-16**, so an ASCII
`grep -a` for a commit hash finds nothing in a binary that contains it. Searched as UTF-16LE the
count is 1. A false negative that reads exactly like the defect the check exists to catch — the
check now says which encoding it searches, and why.

Raw: `2026-09-20-build-arm-gcinfo.log`.
