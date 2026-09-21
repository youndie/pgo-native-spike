#!/usr/bin/env bash
# Nine interleaved rounds over THREE arms, in one session on one host.
#
# Every line carries the host, the CPU and a session id, because this study has now twice
# compared a number from one protocol against a number from another and not noticed. A level
# that drifts 20 % between sessions on the same machine is only comparable inside one run.
set -uo pipefail
N=${N:-20000000}
MODE=${MODE:-skewed}
ROUNDS=${ROUNDS:-9}
SESSION="$(date +%s)-$$"
HOST="$(hostname)"
CPU="$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | sed 's/^ *//;s/ \+/ /g')"
echo "# host=$HOST cpu=$CPU session=$SESSION mode=$MODE n=$N rounds=$ROUNDS"
for r in $(seq 1 "$ROUNDS"); do
  for arm in "$@"; do
    "./$arm.kexe" "$N" "$MODE" 2>/dev/null | grep ' ns/op ' | while read -r label ns rest; do
      echo "$MODE $arm $r $label $ns ns/op sink=0"
    done
  done
done
