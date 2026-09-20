#!/usr/bin/env bash
# RQ1: where the CPU goes, per endpoint, on the pinned arm.
#
#   SUBJECT=bench-a GENERATOR=bench-b SUBJECT_IP=10.0.0.2 bench/ceiling.sh
#
# Call graphs are recorded (`-g`) because the brief wants the INCLUSIVE share of Kotlin callers
# beside the self share: self attribution understates the ceiling, since a sample in the allocator
# reached from Kotlin counts as runtime though a promoted and inlined call might have removed the
# allocation's cause. With `-g`, `perf script` prints the leaf first and its callers after, one
# stack per blank-line-separated block - so the leaf is the FIRST line of a block, not every line.
# Treating every line as a leaf is how a call-graph profile silently becomes a different
# measurement.
set -uo pipefail
SUBJECT=${SUBJECT:?}; GENERATOR=${GENERATOR:?}; SUBJECT_IP=${SUBJECT_IP:?}
BINARY=${BINARY:-xyk-pagedoff}; RATE=${RATE:-200}; DURATION=${DURATION:-45s}
SECRET=bench-secret; ENDPOINT=hook-1; OUT=${OUT:-logs/b-07}
CTL=/tmp/pgo-ceiling-%r@%h:%p
MUX=(-o ControlMaster=auto -o "ControlPath=$CTL" -o ControlPersist=120 -o BatchMode=yes)
s() { ssh -n "${MUX[@]}" "$SUBJECT" "$@"; }
g() { ssh -n "${MUX[@]}" "$GENERATOR" "$@"; }
mkdir -p "$OUT/raw"
BODY='{"zen":"Non-blocking is better than blocking."}'
SIG=$(printf %s "$BODY" | openssl dgst -sha256 -hmac "$SECRET" -hex | sed 's/.*= //')

s "pkill -x $BINARY 2>/dev/null; for i in \$(seq 1 30); do ss -ltnH 'sport = :8091' | grep -q . || break; sleep 1; done
rm -rf /root/b07-run; mkdir -p /root/b07-run; cd /root
export XYK_BOOTSTRAP_ENDPOINT_ID=$ENDPOINT XYK_BOOTSTRAP_SECRET=$SECRET XYK_BOOTSTRAP_SUBSCRIBERS=https://sink.invalid/a
XYK_DB_PATH=/root/b07-run/a.db XYK_PORT=8091 setsid nohup ./$BINARY > /root/b07-run/a.log 2>&1 </dev/null & disown -a
for i in \$(seq 1 60); do sleep 0.5; curl -sf -o /dev/null http://127.0.0.1:8091/health/ready && { echo ready; exit 0; }; done
echo 'never ready' >&2; exit 2" || exit 2
PID=$(s "ss -lptnH 'sport = :8091' | grep -oE 'pid=[0-9]+' | head -1 | cut -d= -f2")
echo "subject pid $PID, nproc $(s nproc)"

run() {
  local name=$1 arm=$2 path=$3
  echo "=== $name at $RATE rps ==="
  g "setsid nohup env TARGET='http://$SUBJECT_IP:8091$path' ARM='$arm' RATE=$RATE DURATION=$DURATION \
     CONNECTIONS=200 BODY='$BODY' SIGNATURE='$SIG' k6 run --quiet /tmp/pgo-ingest.js \
     > /tmp/k6-$name.log 2>&1 </dev/null & disown -a; echo started" >/dev/null
  sleep 4
  s "perf record -q -g -e cpu-clock -F 999 -o /tmp/ceil-$name.data -p $PID -- sleep 35" 2>&1 | tail -1
  s "perf script -i /tmp/ceil-$name.data -F ip,sym,dso 2>/dev/null" > "$OUT/raw/$name-stacks.txt"
  sleep 6
  g "grep -E 'http_reqs|dropped_iterations|http_req_failed|p\(99\)' /tmp/k6-$name.log | head -4" > "$OUT/raw/$name-k6.txt" 2>&1
  echo "  stacks file: $(wc -l < "$OUT/raw/$name-stacks.txt") lines"
  sed 's/^/    /' "$OUT/raw/$name-k6.txt"
  sleep 15
}

run ingest   ingest  "/hooks/$ENDPOINT"
run journal  control "/journal"
run apievents control "/api/events"
run health   control "/health/live"
s "pkill -x $BINARY"
echo "done"
