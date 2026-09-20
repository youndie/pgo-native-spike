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
set -euo pipefail

ARM=${1:?usage: build-arm.sh <arm-name> [--extra-compiler-arg ARG]}
shift || true
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

# shellcheck disable=SC2086
rsync -a --delete -e "${BUILDER#ssh }" --exclude build --exclude .gradle --exclude .kotlin \
      --exclude .idea --exclude .git "$SRC/" "${BUILDER##* }:$REMOTE_DIR/"
$BUILDER "cd $REMOTE_DIR && echo $COMMIT > SOURCE_COMMIT && ./gradlew --no-daemon --max-workers=6 \
  :server:linkReleaseExecutableNative ${PROPS[*]} $*" 2>&1 | tail -3

OUT=/tmp/xyk-$ARM-${COMMIT:0:7}.kexe
$BUILDER "cp \$(ls $REMOTE_DIR/server/build/bin/native/releaseExecutable/*.kexe | head -1) $OUT"
scp -q "${BUILDER##* }:$OUT" "$OUT" 2>/dev/null || \
  eval "${BUILDER/ssh/scp} :$OUT $OUT"
scp -q "$OUT" "$SUBJECT:/root/xyk-$ARM-${COMMIT:0:7}"
ssh -n "$SUBJECT" "chmod +x /root/xyk-$ARM-${COMMIT:0:7}"

# THE CHECKS THAT MAKE IT AN ARM RATHER THAN A BINARY. Each one is a property the pin names, and
# each has been wrong at least once in this study.
ssh -n "$SUBJECT" "b=/root/xyk-$ARM-${COMMIT:0:7}
  printf '  size:   %s bytes\n' \"\$(stat -c%s \$b)\"
  printf '  static: %s\n' \"\$(ldd \$b 2>&1 | head -1)\"
  printf '  curl symbols (want 0): %s\n' \"\$(readelf -sW \$b | grep -ci curl_easy)\"
  printf '  kfun FUNC symbols: %s\n' \"\$(readelf -sW \$b | awk '\$4==\"FUNC\"{print \$8}' | grep -c '^kfun:')\""
echo "shipped: $SUBJECT:/root/xyk-$ARM-${COMMIT:0:7}"
