#!/usr/bin/env python3
"""Link razves's in-process sampler into a COPY of xyk, for B-15's cross-check of RQ1.

    patches/razves-sampler.py <path-to-a-copy-of-xyk> [sampler-version]

**This is measurement scaffolding and it is deliberately not a pull request to xyk.** B-19's two
changes went upstream because each was useful to the service on its own; a profiler start/stop
wired into `main` is useful only to whoever is measuring, so it lives here, applies to a copy, and
is reproducible from this repository. The copy is what gets built; the product is untouched.

What it does, and why each piece is where it is:

  * `Sampler` is in `nativeMain` and `main()` is in `commonMain`, so the hook is an `expect` with a
    no-op `jvm` actual. Without that the JVM target stops compiling and the arm stops being
    "otherwise identical to the pinned build".
  * The dependency is declared for linuxX64 only. razves publishes the sampler per target and the
    native target here is macosArm64 when the build runs on a Mac - the same shape xyk already uses
    for chronik and kafkakn.
  * Sampling is off unless `RAZVES_HZ` is set, so the patched binary with the variable unset is the
    pinned binary plus dead code, which is what makes the size delta meaningful.
"""
import re
import sys
from pathlib import Path

VERSION = sys.argv[2] if len(sys.argv) > 2 else "0.1.0.33"
root = Path(sys.argv[1]) if len(sys.argv) > 1 else sys.exit(__doc__)
server = root / "server"
if not (server / "build.gradle.kts").is_file():
    sys.exit(f"{root} does not look like a copy of xyk")

# --- 1. the hook, declared in common and answered per target -----------------------------------
(server / "src/commonMain/kotlin/io/github/youndie/xyk/RazvesHook.kt").write_text('''package io.github.youndie.xyk

/**
 * Starts razves's in-process sampler when `RAZVES_HZ` is set, and returns what stops it.
 *
 * Applied by pgo-native-spike's `patches/razves-sampler.py` for B-15 and present in no shipped
 * build. Unset, this is a branch not taken.
 */
internal expect fun startRazves(): (() -> Unit)?
''')

(server / "src/jvmMain/kotlin/io/github/youndie/xyk/RazvesHook.jvm.kt").write_text('''package io.github.youndie.xyk

/** No sampler on the JVM: razves samples a Kotlin/Native process. */
internal actual fun startRazves(): (() -> Unit)? = null
''')

(server / "src/nativeMain/kotlin/io/github/youndie/xyk/RazvesHook.native.kt").write_text('''package io.github.youndie.xyk

import io.github.youndie.razves.sampler.Sampler
import kotlinx.cinterop.ExperimentalForeignApi
import kotlinx.cinterop.toKString
import platform.posix.getenv

@OptIn(ExperimentalForeignApi::class)
internal actual fun startRazves(): (() -> Unit)? {
    val hz = getenv("RAZVES_HZ")?.toKString()?.toIntOrNull() ?: return null
    val out = getenv("RAZVES_DUMP")?.toKString() ?: "/tmp/xyk.dump"
    Sampler.start(hz)
    println("xyk: razves sampling at $hz Hz, dump to $out")
    return {
        Sampler.stop()
        // taken and dropped are printed BEFORE the write: a dump that never reaches disk should
        // still say how many samples it was going to carry, and dropped is part of the profile
        // rather than a log line - percentages over a ring that overflowed are wrong invisibly.
        println("xyk: razves taken=${Sampler.taken} dropped=${Sampler.dropped}")
        Sampler.writeDump(out, hz = hz)
        println("xyk: razves dump written to $out")
    }
}
''')

# --- 2. the dependency, linuxX64 only ----------------------------------------------------------
build = (server / "build.gradle.kts").read_text()
anchor = "    sourceSets {"
if "razves" not in build:
    dep = '''    // B-15 (pgo-native-spike): razves's in-process sampler, as a second implementation to check
    // RQ1's buckets against. linuxX64 only - the sampler is published per target and `native` is
    // macosArm64 on a Mac, the same reason chronik and kafkakn are declared the way they are.
    if (nativeTarget.name == "native" && System.getProperty("os.name") == "Linux") {
        sourceSets.named("nativeMain").configure {
            dependencies { implementation("io.github.youndie.razves:sampler:%s") }
        }
    }

''' % VERSION
    build = build.replace(anchor, dep + anchor, 1)

# --- 3. the two call sites ---------------------------------------------------------------------
main_path = server / "src/commonMain/kotlin/io/github/youndie/xyk/Main.kt"
main = main_path.read_text()
start_anchor = "    // Here, before the engine: a server that opened its port ahead of a ready schema"
assert start_anchor in main, "Main.kt does not look like the pinned revision"
main = main.replace(
    start_anchor,
    "    val stopRazves = startRazves()\n\n" + start_anchor,
    1,
)
# After runUntilSignal returns: the engine has drained and the pool is closed, so what the sampler
# saw is the whole run rather than a prefix of it.
tail = "            telemetry(\n                participant(\"DI container\") {"
assert tail in main
main = main.replace(
    tail,
    "            telemetry(participant(\"razves\") { stopRazves?.invoke() })\n\n" + tail,
    1,
)
main_path.write_text(main)
(server / "build.gradle.kts").write_text(build)
print(f"patched {root}: sampler {VERSION}, hook in 3 source sets, 2 call sites in Main.kt")
