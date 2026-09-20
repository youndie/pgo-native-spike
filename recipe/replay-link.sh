#!/usr/bin/env bash
# Replay the link command the Kotlin/Native build prints, substituting a PGO object.
#
# WHY. `-Xcompile-from-bitcode` has no klib graph, so `DependenciesTracker` contributes nothing
# and every native symbol a klib would have supplied goes undefined - rd_kafka_*, sqlx4k_*, and
# no reason to think those are the last. Passing archives by hand is unbounded and is a way for
# two arms to differ. The build already prints the exact link line; this replays it.
#
#   ./recipe/replay-link.sh capture  <outdir> -- <kotlinc args...>   # normal build: link line + IR
#   ./recipe/replay-link.sh train    <outdir>                        # instrumented binary
#
# WHAT WORKS AND WHAT DOES NOT, measured (logs/b-22/):
#   * Replaying the captured line with the compiler's OWN object reproduces the ordinary build
#     BYTE FOR BYTE. The replay itself is exact.
#   * The TRAINING arm works end to end: instrumented bitcode carries no profile metadata, so
#     kotlinc runs its own full pipeline and emits the object even when its own link step fails.
#     Replaying the line with that object plus the profile runtime gives a binary that runs and
#     writes an IR-level profile.
#   * The USE arm does NOT work on stock 2.4.20. See the note at the bottom.

set -euo pipefail
STEP="preflight"
trap 'echo; echo "FAILED at: $STEP" >&2; exit 1' ERR

MODE="${1:?usage: replay-link.sh capture|train <outdir> [-- kotlinc args]}"
OUT="${2:?an output directory}"
shift 2
[ "${1:-}" = "--" ] && shift || true

: "${KN:=$(ls -d "$HOME"/.konan/kotlin-native-prebuilt-*-2.4.20 2>/dev/null | head -1)}"
[ -x "$KN/bin/kotlinc-native" ] || { echo "set KN to a kotlin-native-prebuilt-* directory" >&2; exit 1; }
if [ -z "${L:-}" ]; then
    for d in "$HOME"/.konan/dependencies/llvm-*-dev-*; do [ -x "$d/bin/opt" ] && L="$d" && break; done
fi
[ -x "${L:-}/bin/opt" ] || { echo "no LLVM bundle with 'opt'; see recipe/pgo.sh preflight" >&2; exit 1; }
mkdir -p "$OUT"; OUT="$(cd "$OUT" && pwd)"

case "$MODE" in
capture)
    # -Xverbose-phases=Linker prints the ld.lld invocation in full; -Xtemporary-files-dir keeps
    # the compiler's own object, which is what the line refers to and what the control needs.
    STEP="capture the ordinary build"
    mkdir -p "$OUT/ir" "$OUT/tmp"
    "$KN/bin/kotlinc-native" -opt \
        -Xtemporary-files-dir="$OUT/tmp" \
        -Xsave-llvm-ir-directory="$OUT/ir" -Xsave-llvm-ir-after=LinkBitcodeDependencies \
        -Xverbose-phases=Linker -o "$OUT/base" "$@" > "$OUT/build.log" 2>&1
    grep -oE "/[^ ]*ld\.lld .*" "$OUT/build.log" | head -1 > "$OUT/link.cmd"
    [ -s "$OUT/link.cmd" ] || { echo "no ld.lld line in the build output" >&2; exit 1; }
    OBJ=$(grep -oE "[^ ]+\.o\b" "$OUT/link.cmd" | grep -F "$OUT/tmp/" | head -1)
    [ -n "$OBJ" ] || { echo "the link line names no object under $OUT/tmp" >&2; exit 1; }
    echo "$OBJ" > "$OUT/compiler.obj"
    IR="$OUT/ir/out.LinkBitcodeDependencies.ll"
    [ -s "$IR" ] || { echo "no IR at $IR (does the directory exist? kotlinc warns and exits 0)" >&2; exit 1; }
    echo "link line:        $(wc -c < "$OUT/link.cmd") bytes"
    echo "compiler object:  $OBJ"
    echo "IR:               $(grep -c '^define' "$IR") defines"

    # THE CONTROL. A replay that changes the binary is not a replay.
    STEP="control: replay with the compiler's own object"
    sed "s|-o $OUT/base\.kexe|-o $OUT/control.kexe|" "$OUT/link.cmd" > "$OUT/control.sh"
    bash "$OUT/control.sh"
    if cmp -s "$OUT/control.kexe" "$OUT/base.kexe"; then
        echo "control:          BYTE-IDENTICAL to the ordinary build"
    else
        echo "control:          differs from the ordinary build - the replay is NOT exact" >&2
        ls -l "$OUT/control.kexe" "$OUT/base.kexe" >&2
        exit 1
    fi
    ;;
train)
    STEP="instrument"
    IR="$OUT/ir/out.LinkBitcodeDependencies.ll"
    [ -s "$IR" ] && [ -s "$OUT/link.cmd" ] || { echo "run 'capture' into $OUT first" >&2; exit 1; }
    "$L/bin/opt" -passes="pgo-instr-gen,instrprof" "$IR" -o "$OUT/instr.bc"

    STEP="build the profile runtime with an IR-level version variable"
    printf 'long long __llvm_profile_raw_version = (1LL << 56) | 10;\n' > "$OUT/version.c"
    "$L/bin/clang" -c -o "$OUT/version.o" "$OUT/version.c"
    RT="$(ls "$L"/lib/clang/*/lib/*/libclang_rt.profile.a | head -1)"
    rm -rf "$OUT/rtx"; mkdir "$OUT/rtx"
    (cd "$OUT/rtx" && "$L/bin/llvm-ar" x "$RT" && rm -f InstrProfilingVersionVar.c.o \
        && cp ../version.o . && "$L/bin/llvm-ar" rcs ../libprofile-ir.a ./*.o)

    # kotlinc's own link step is EXPECTED to fail on a subject with native dependencies. It emits
    # the object first, and the object is the only thing wanted from it.
    STEP="let kotlinc run its pipeline and emit the object"
    rm -rf "$OUT/tI"; mkdir "$OUT/tI"
    "$KN/bin/kotlinc-native" -opt -Xcompile-from-bitcode="$OUT/instr.bc" \
        -Xtemporary-files-dir="$OUT/tI" -o "$OUT/discard" > "$OUT/train-compile.log" 2>&1 \
        || echo "   kotlinc's own link failed, as expected; taking its object"
    OBJ=$(ls "$OUT"/tI/*.o 2>/dev/null | head -1)
    [ -n "$OBJ" ] || { echo "kotlinc emitted no object - it failed before codegen" >&2; exit 1; }
    echo "   object: $OBJ ($(stat -c%s "$OBJ") bytes)"

    STEP="replay the link for the instrumented binary"
    sed "s|$(cat "$OUT/compiler.obj")|$OBJ|; s|-o $OUT/base\.kexe|-o $OUT/train.kexe|" \
        "$OUT/link.cmd" > "$OUT/train.sh"
    grep -qF "$OBJ" "$OUT/train.sh" || { echo "the object substitution did not take" >&2; exit 1; }
    # Only the TRAINING binary links the profile runtime; no measured arm does.
    # This must extend the SAME line: appended as a new line it becomes a separate command, the
    # link runs without the runtime, and every __llvm_profile_* symbol comes back undefined.
    sed -i "s|\$| -u__llvm_profile_runtime $OUT/libprofile-ir.a|" "$OUT/train.sh"
    grep -qF -- "-u__llvm_profile_runtime" "$OUT/train.sh" && [ "$(wc -l < "$OUT/train.sh")" = "1" ] \
        || { echo "the profile runtime did not land on the link line" >&2; exit 1; }
    bash "$OUT/train.sh"
    echo "   linked: $OUT/train.kexe ($(stat -c%s "$OUT/train.kexe") bytes)"
    echo
    echo "Run it under the workload with LLVM_PROFILE_FILE=<dir>/%p.profraw, then:"
    echo "  $L/bin/llvm-profdata merge -output=p.profdata <dir>/*.profraw"
    echo "  $L/bin/llvm-profdata show p.profdata | grep -i 'instrumentation level'   # must say IR"
    ;;
*) echo "unknown mode: $MODE" >&2; exit 1 ;;
esac

cat <<'NOTE'

THE USE ARM IS NOT REACHABLE THIS WAY ON STOCK 2.4.20, and this is the finding, not a to-do.
A module carrying profile metadata makes kotlinc emit the "CG Profile" module flag twice - once
from its LTO pipeline and once from the clang++ codegen step - and the module is then rejected:
  module flag identifiers must be unique (or of 'require' type) !"CG Profile"
The only -Xllvm-lto-passes value that avoids it is one that does no LTO ("verify"), and the
optimisation then has to be supplied externally. `opt -passes=default<O3>` does NOT stand in for
what Kotlin/Native's own LTO does: it internalises and DCEs 3 027 defines down to 411, and the
externally optimised binary came out 3.8x larger than the ordinary build. So a USE arm built this
way is not comparable to the pinned build, which is what an A3 arm would have to be.
NOTE
