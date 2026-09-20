#!/usr/bin/env bash
# Build one arm of the study off-host and ship it to the subject.
#
#   BUILDER='ssh -p 2222 youndie@127.0.0.1' SUBJECT=bench-a bench/build-arm.sh a0
#   ... bench/build-arm.sh a0 --extra-compiler-arg -Xruntime-logs=gc=info
#
# WHY OFF-HOST AT ALL. `bench-a` is the only machine the subject is measured on and it cannot
# build the subject: it has no public IPv4, so `github.com`, `cache-redirector.jetbrains.com` and
# `reposilite.kotlin.website` - which serves the catalog the build takes its compiler version
# from - are all unreachable. It runs binaries; it does not make them.
#
# WHY THE SOURCE IS COPIED AND NOT CLONED. `gh` on the builder is not authenticated, and a copy
# of the working tree is a stronger guarantee than a same-named ref: it is the exact bytes that
# were measured. The price is that `.git` does not travel, so the commit is written beside the
# tree and stamped into the build - see the next paragraph, which is a defect this script exists
# to stop repeating.
#
# THE COMMIT MUST REACH THE BINARY. The binary this study started on answers `/version` with a
# build timestamp and `commit: unknown`, because it was built from a tree without `.git`. Its
# source is now unrecoverable, which is why it stopped being the baseline. The first version of
# this recipe reproduced the same defect within the hour. A baseline that cannot be rebuilt is
# not a baseline, so the commit is passed in and asserted afterwards.
#
# "Asserted afterwards" was aspirational until B-19: the commit was written to a file nothing
# read, and none of the checks below looked for it. Both halves are real now - the build gets
# SOURCE_COMMIT in its environment, and the binary is grepped for the string it should have
# compiled in. A provenance mechanism nobody checks is how this defect survived two rebuilds.
set -euo pipefail

ARM=${1:?usage: build-arm.sh <arm-name> [--extra-compiler-arg ARG]...}
shift || true

# `--extra-compiler-arg X` becomes `-Pxyk.extraCompilerArgs="X ..."`. It used to be passed through
# to gradlew verbatim, which is not a Gradle flag and made the documented invocation fail; the
# property it needs did not exist in xyk until B-19 added it. Anything else is passed through.
EXTRA_ARGS=()
PASSTHROUGH=()
while [ $# -gt 0 ]; do
  case "$1" in
    --extra-compiler-arg) EXTRA_ARGS+=("${2:?--extra-compiler-arg needs a value}"); shift 2 ;;
    *) PASSTHROUGH+=("$1"); shift ;;
  esac
done
# `${arr[*]}` on an EMPTY array is an unbound variable under `set -u` in the bash this mac ships
# (3.2), so both of these are expanded with `:-` at the point of use.
if [ ${#EXTRA_ARGS[@]} -gt 0 ]; then PROPS_EXTRA=("-Pxyk.extraCompilerArgs=${EXTRA_ARGS[*]}"); else PROPS_EXTRA=(); fi
SRC=${SRC:-/Users/youndie/Documents/GitHub/xyk}
BUILDER=${BUILDER:?set BUILDER to an ssh command reaching the build host}
SUBJECT=${SUBJECT:?set SUBJECT to the ssh destination of the host under test}
REMOTE_DIR=${REMOTE_DIR:-xyk-build-$ARM}

# THE PINNED CONFIGURATION, and all four axes are named rather than left to defaults: two of the
# defaults differ from the arm the stand was measured on.
PROPS=(-Pxyk.httpClient=false -Pxyk.outbound=real -Pxyk.staticLink=true -Pxyk.allocator=paged-off)

COMMIT=$(git -C "$SRC" rev-parse HEAD)
if [ -n "$(git -C "$SRC" status --porcelain)" ]; then
  echo "build-arm: $SRC is dirty; a binary built from an uncommitted tree has no provenance" >&2
  exit 2
fi
echo "arm $ARM from $COMMIT"

# HOW BUILDER IS TAKEN APART, because the documented invocation did not work until B-19.
# BUILDER is a whole ssh command - "ssh -p 2222 youndie@127.0.0.1" - so the transport for rsync
# is everything except the destination, and the destination is the last word. It used to strip
# the leading "ssh" instead, handing rsync "-p 2222 youndie@127.0.0.1" as the remote shell and
# failing with `exec on '-p'`. Any BUILDER carrying an option hit it.
BUILDER_SSH="${BUILDER% *}"
BUILDER_HOST="${BUILDER##* }"

# shellcheck disable=SC2086
rsync -a --delete -e "$BUILDER_SSH" --exclude build --exclude .gradle --exclude .kotlin \
      --exclude .idea --exclude .git "$SRC/" "$BUILDER_HOST:$REMOTE_DIR/"
# SOURCE_COMMIT is exported, not just written to a file: xyk's build reads it from the
# ENVIRONMENT (kore's build-identity plugin takes a commit for exactly this case). The file is
# kept because it is what says, on the build host, which revision that tree is.
$BUILDER "cd $REMOTE_DIR && echo $COMMIT > SOURCE_COMMIT && SOURCE_COMMIT=$COMMIT ./gradlew --no-daemon --max-workers=6 \
  :server:linkReleaseExecutableNative ${PROPS[*]} ${PROPS_EXTRA[*]:-} ${PASSTHROUGH[*]:-}" 2>&1 | tail -3

OUT=/tmp/xyk-$ARM-${COMMIT:0:7}.kexe
$BUILDER "cp \$(ls $REMOTE_DIR/server/build/bin/native/releaseExecutable/*.kexe | head -1) $OUT"
# Fetched over the BUILDER command itself rather than scp. scp does not take ssh's options - a
# port is -P, not -p - so every variant of "turn BUILDER into an scp" is a way to silently copy
# the wrong thing or nothing. `cat` needs no translation.
$BUILDER "cat $OUT" > "$OUT"
[ -s "$OUT" ] || { echo "build-arm: nothing came back from the builder" >&2; exit 3; }
scp -q "$OUT" "$SUBJECT:/root/xyk-$ARM-${COMMIT:0:7}"
ssh -n "$SUBJECT" "chmod +x /root/xyk-$ARM-${COMMIT:0:7}"

# THE CHECKS THAT MAKE IT AN ARM RATHER THAN A BINARY. Each one is a property the pin names, and
# each has been wrong at least once in this study.
#
# The commit check searches UTF-16LE, and that is not a detail: **Kotlin/Native stores string
# literals as UTF-16**, so `grep -a` for an ASCII commit hash finds nothing in a binary that
# contains it. The first version of this check did exactly that and reported 0 against a
# binary whose generated source carried the right commit - a false negative that reads
# identically to the defect the check was added to catch.
ssh "$SUBJECT" bash -s -- "/root/xyk-$ARM-${COMMIT:0:7}" "${COMMIT:0:12}" <<'REMOTE'
set -u
b=$1
want=$2
printf '  size:   %s bytes\n' "$(stat -c%s "$b")"
printf '  static: %s\n' "$(ldd "$b" 2>&1 | head -1)"
printf '  curl symbols (want 0): %s\n' "$(readelf -sW "$b" | grep -ci curl_easy)"
printf '  kfun FUNC symbols: %s\n' "$(readelf -sW "$b" | awk '$4=="FUNC"{print $8}' | grep -c '^kfun:')"
printf '  commit compiled in (want >=1): %s\n' \
  "$(python3 -c "import sys;print(open(sys.argv[1],'rb').read().count(sys.argv[2].encode('utf-16-le')))" "$b" "$want")"
REMOTE
echo "shipped: $SUBJECT:/root/xyk-$ARM-${COMMIT:0:7}"
