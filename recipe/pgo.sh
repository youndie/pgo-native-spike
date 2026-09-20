#!/usr/bin/env bash
# Instrumentation PGO on a Kotlin/Native program, on stock tools. No fork.
#
# What this covers: the full instrument -> train -> merge -> apply cycle for a SELF-CONTAINED
# program, which is what RQ0 established. It is NOT a recipe for a real service; see the two
# obstacles listed at the bottom of this file, and docs/research/2026-09-20-instrumentation-pgo.md.
#
#   ./recipe/pgo.sh probes/dispatch-bench.kt [outdir]
#
# Every step that can fail silently is asserted. The script cannot exit 0 after a failed step:
# an ERR trap says which one broke, because a PGO pipeline that quietly applies nothing looks
# exactly like one that worked.

set -euo pipefail

STEP="preflight"
trap 'echo; echo "FAILED at: $STEP" >&2; exit 1' ERR

SRC="${1:?usage: pgo.sh <source.kt> [outdir]}"
OUT="${2:-$PWD/pgo-out}"
[ -f "$SRC" ] || { echo "no such source: $SRC" >&2; exit 1; }
SRC="$(cd "$(dirname "$SRC")" && pwd)/$(basename "$SRC")"

# --- preflight -------------------------------------------------------------------------------
# The essentials LLVM bundle that a normal Kotlin/Native install pulls has clang, llvm-ar and
# llvm-profdata but NOT opt, and opt is what runs the two PGO passes. konan.properties names the
# dev bundle in llvm.<target>.dev; it is a separate download.
: "${KN:=$(ls -d "$HOME"/.konan/kotlin-native-prebuilt-*-2.4.20 2>/dev/null | head -1)}"
[ -n "${KN:-}" ] && [ -x "$KN/bin/kotlinc-native" ] || {
    echo "set KN to a kotlin-native-prebuilt-* directory (found none under ~/.konan)" >&2; exit 1; }

if [ -z "${L:-}" ]; then
    for d in "$HOME"/.konan/dependencies/llvm-*-dev-*; do
        [ -x "$d/bin/opt" ] && L="$d" && break
    done
fi
[ -n "${L:-}" ] && [ -x "$L/bin/opt" ] || {
    echo "no LLVM bundle with 'opt' found." >&2
    echo "The 'essentials' bundle does not ship opt; you need the 'dev' one named by" >&2
    echo "  grep llvm.<target>.dev \$KN/konan/konan.properties" >&2
    echo "from \$(grep dependenciesUrl \$KN/konan/konan.properties)/resources/llvm/<ver>/<name>.tar.gz" >&2
    echo "Then set L=<that directory>." >&2
    exit 1; }

RT="$L/lib/clang/21/lib/x86_64-unknown-linux-gnu/libclang_rt.profile.a"
[ -f "$RT" ] || RT="$(ls "$L"/lib/clang/*/lib/*/libclang_rt.profile.a 2>/dev/null | head -1)"
[ -f "$RT" ] || { echo "no libclang_rt.profile.a under $L" >&2; exit 1; }

mkdir -p "$OUT" && cd "$OUT"
echo "kotlin-native: $KN"
echo "llvm:          $L"
echo "source:        $SRC"
echo "out:           $OUT"
echo

# --- 1. baseline, and its IR ------------------------------------------------------------------
# -Xsave-llvm-ir-after=LinkBitcodeDependencies is the point where the Kotlin code and the runtime
# bitcode are in one module. Instrumenting earlier misses the runtime; later is past the pipeline.
# The directory must already exist: if it does not, kotlinc prints "cannot dump LLVM IR to
# non-existent location", writes nothing, and still exits 0.
STEP="1/7 compile the baseline and dump its IR"
echo "== $STEP"
rm -rf ir && mkdir -p ir && "$KN/bin/kotlinc-native" -opt \
    -Xsave-llvm-ir-directory="$OUT/ir" -Xsave-llvm-ir-after=LinkBitcodeDependencies \
    -o a0 "$SRC" > kotlinc-a0.log 2>&1
IR="$OUT/ir/out.LinkBitcodeDependencies.ll"
[ -s "$IR" ] || { echo "the compiler produced no IR at $IR" >&2; exit 1; }
echo "   IR: $(wc -c < "$IR") bytes, $(grep -c '^define' "$IR") defines"

# --- 2. instrument ------------------------------------------------------------------------------
STEP="2/7 run pgo-instr-gen,instrprof"
echo "== $STEP"
"$L/bin/opt" -passes="pgo-instr-gen,instrprof" "$IR" -o instr.bc
# Assert the pass actually inserted counters. An opt that silently no-ops leaves a valid module.
CNT=$("$L/bin/llvm-dis" -o - instr.bc 2>/dev/null | grep -c '__profc_' || true)
[ "$CNT" -gt 0 ] || { echo "instrprof inserted no __profc_ counters" >&2; exit 1; }
echo "   $CNT references to __profc_ counters in the instrumented module"

# --- 3. the version variable ----------------------------------------------------------------
# LOAD-BEARING. libclang_rt.profile.a ships InstrProfilingVersionVar.c.o declaring the raw profile
# version as front-end. A profile written with that version merges as Front-end, and pgo-instr-use
# refuses a front-end profile. Replacing the object with an IR-level version is the whole fix.
STEP="3/7 rebuild the profile runtime with an IR-level version variable"
echo "== $STEP"
printf 'long long __llvm_profile_raw_version = (1LL << 56) | 10;\n' > version.c
"$L/bin/clang" -c -o version.o version.c
rm -rf rtx && mkdir rtx && (cd rtx && "$L/bin/llvm-ar" x "$RT" \
    && rm -f InstrProfilingVersionVar.c.o && cp ../version.o . \
    && "$L/bin/llvm-ar" rcs ../libprofile-ir.a ./*.o)
[ -f libprofile-ir.a ] && ! "$L/bin/llvm-ar" t libprofile-ir.a | grep -q InstrProfilingVersionVar \
    || { echo "the stock version object is still in the archive" >&2; exit 1; }
echo "   libprofile-ir.a: $("$L/bin/llvm-ar" t libprofile-ir.a | wc -l) objects, stock version object removed"

# --- 4. link the instrumented binary ---------------------------------------------------------
# LOAD-BEARING. -u__llvm_profile_runtime forces the runtime's registration object in. Without it
# the link succeeds, the binary runs, and it writes no profile at all.
STEP="4/7 link the instrumented binary"
echo "== $STEP"
"$KN/bin/kotlinc-native" -opt -Xcompile-from-bitcode="$OUT/instr.bc" \
    -linker-option -u__llvm_profile_runtime -linker-option "$OUT/libprofile-ir.a" \
    -o a1 > kotlinc-a1.log 2>&1
[ -x a1.kexe ] || { echo "no a1.kexe produced" >&2; exit 1; }

# --- 5. train ---------------------------------------------------------------------------------
STEP="5/7 run the instrumented binary and collect a profile"
echo "== $STEP"
rm -f ./*.profraw
LLVM_PROFILE_FILE="$OUT/i-%p.profraw" ./a1.kexe > train.log 2>&1 || true
ls ./*.profraw > /dev/null 2>&1 || {
    echo "the instrumented binary wrote no .profraw." >&2
    echo "That is what a missing -u__llvm_profile_runtime looks like." >&2; exit 1; }
echo "   $(ls ./*.profraw | wc -l) profraw, $(du -ch ./*.profraw | tail -1 | cut -f1) total"

# --- 6. merge, and check it is IR-level -------------------------------------------------------
STEP="6/7 merge the profile"
echo "== $STEP"
"$L/bin/llvm-profdata" merge -output=i.profdata ./*.profraw
"$L/bin/llvm-profdata" show i.profdata > profdata-show.txt
grep -qi 'Instrumentation level: IR' profdata-show.txt || {
    echo "the profile merged as front-end, not IR. Step 3 did not take." >&2
    grep -i 'instrumentation level' profdata-show.txt >&2 || true; exit 1; }
# Vacuity guard: a profile of all-zero counters is IR-level and applies to nothing.
MAXC=$(awk '/Maximum function count/ {print $NF}' profdata-show.txt | head -1)
[ -n "$MAXC" ] && [ "$MAXC" -gt 0 ] || {
    echo "the profile is IR-level but every counter is zero - the training run did no work" >&2; exit 1; }
echo "   $(awk '/Total functions/ {print $NF}' profdata-show.txt | head -1) functions, max count $MAXC"

# --- 7. apply, and prove it changed the module ------------------------------------------------
# The real oracle. A pipeline that runs cleanly and applies nothing is the failure mode worth
# guarding: compare branch-weight metadata against the same module built without the profile.
STEP="7/7 apply the profile and verify it took"
echo "== $STEP"
"$L/bin/opt" -passes="pgo-instr-use" -pgo-test-profile-file="$OUT/i.profdata" "$IR" -o applied.bc
"$L/bin/llvm-dis" -o applied.ll applied.bc
BASE_PROF=$(grep -c '!prof' "$IR" || true)
APPL_PROF=$(grep -c '!prof' applied.ll || true)
[ "$APPL_PROF" -gt "$BASE_PROF" ] || {
    echo "applying the profile added no !prof metadata ($BASE_PROF -> $APPL_PROF)" >&2; exit 1; }
ENTRY=$(grep -c 'entry_count' applied.ll || true)
echo "   !prof metadata: $BASE_PROF -> $APPL_PROF;  functions with an entry count: $ENTRY"

echo
echo "OK. The profile is at $OUT/i.profdata and the annotated module at $OUT/applied.ll."
echo "To build an optimised binary from it, add the use pass to the normal pipeline:"
echo "  \$KN/bin/kotlinc-native -opt -Xllvm-module-passes='pgo-instr-use' ..."
echo "  (-pgo-test-profile-file is an opt flag; through kotlinc the profile goes in the same way"
echo "   the passes above were run, which is why this script stops at the annotated module.)"
echo
cat <<'NOTE'
NOT covered, and both are why this did not reach the service in this study:
  1. A fully static link. The profile runtime needs a dynamic executable; -static fails with
     "undefined hidden symbol: _DYNAMIC". Link both arms dynamically and price the change.
  2. Native dependencies from klibs. -Xcompile-from-bitcode has no klib graph, so every native
     symbol a klib would have contributed goes undefined (rd_kafka_*, sqlx4k_*, ...). The fix is
     to replay the linker command the normal build prints, substituting the PGO object, rather
     than resuming from bitcode at all.
NOTE
