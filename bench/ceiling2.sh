#!/usr/bin/env bash
# RQ1's second point: each endpoint at 50-70 % of ITS OWN saturation, per BRIEF amendment A2.2.
#
#   SUBJECT=bench-a GENERATOR=bench-b SUBJECT_IP=10.0.0.2 BINARY=xyk-a0-c4ba99f bench/ceiling2.sh
#
# WHY A SWEEP PER ENDPOINT AND NOT ONE RATE. B-07 took every endpoint at 200 rps and the rate
# turned out to change the answer by 3.7x: `/journal` was saturated there and read 55.55 % Kotlin
# against 14.92 % clean. The knees differ by an order of magnitude - ingest around 350, journal
# well under 100 - so one number cannot be 50-70 % of all of them.
#
# WHY TWO CAPTURES PER ENDPOINT. Frame pointers are absent from optimised Kotlin/Native, so
# B-07's inclusive column was a lower bound: 16.6-34 % of its stacks had no callers at all. A
# dwarf capture fixes that and costs an order of magnitude in size, so it runs at a lower rate and
# only the SELF buckets are read off the cheap capture. Reading self time off a dwarf run at a
# different frequency would be comparing two instruments and calling it one.
#
# WHY THE DATABASE IS SEEDED FIRST, TO A FIXED SIZE. The read endpoints' cost depends on how many
# rows exist, so an unseeded run measures an empty page and a run after a long ingest measures a
# different service. The seed is stated with the results.
set -uo pipefail
# THE SCRIPT MUST NOT EXIT 0 WHEN IT FAILS. The first run died on `declare -A` - macOS ships bash
# 3.2, which has no associative arrays - and still exited 0, so the harness reported success for a
# run that produced one sweep out of four. A driver that cannot fail loudly is the same defect as
# a check that cannot fail.
trap 'rc=$?; [ $rc -ne 0 ] && echo "ceiling2: FAILED at line $LINENO (rc=$rc)" >&2; exit $rc' ERR
FAILED=0
SUBJECT=${SUBJECT:?}; GENERATOR=${GENERATOR:?}; SUBJECT_IP=${SUBJECT_IP:?}
BINARY=${BINARY:-xyk-a0-c4ba99f}; SECRET=bench-secret; ENDPOINT=hook-1; OUT=${OUT:-logs/b-17}
SEED_SECONDS=${SEED_SECONDS:-30}; SEED_RATE=${SEED_RATE:-200}
CTL=/tmp/pgo-c2-%r@%h:%p
MUX=(-o ControlMaster=auto -o "ControlPath=$CTL" -o ControlPersist=180 -o BatchMode=yes)
s() { ssh -n "${MUX[@]}" "$SUBJECT" "$@"; }
g() { ssh -n "${MUX[@]}" "$GENERATOR" "$@"; }
mkdir -p "$OUT/raw"
BODY='{"zen":"Non-blocking is better than blocking."}'
SIG=$(printf %s "$BODY" | openssl dgst -sha256 -hmac "$SECRET" -hex | sed 's/.*= //')

s "pkill -x $BINARY 2>/dev/null; for i in \$(seq 1 30); do ss -ltnH 'sport = :8091' | grep -q . || break; sleep 1; done
rm -rf /root/b17-run; mkdir -p /root/b17-run; cd /root
export XYK_BOOTSTRAP_ENDPOINT_ID=$ENDPOINT XYK_BOOTSTRAP_SECRET=$SECRET XYK_BOOTSTRAP_SUBSCRIBERS=https://sink.invalid/a
XYK_DB_PATH=/root/b17-run/a.db XYK_PORT=8091 setsid nohup ./$BINARY > /root/b17-run/a.log 2>&1 </dev/null & disown -a
for i in \$(seq 1 60); do sleep 0.5; curl -sf -o /dev/null http://127.0.0.1:8091/health/ready && { echo ready; exit 0; }; done
echo 'never ready' >&2; exit 2" || exit 2
PID=$(s "ss -lptnH 'sport = :8091' | grep -oE 'pid=[0-9]+' | head -1 | cut -d= -f2")
echo "A0=$BINARY pid=$PID nproc=$(s nproc)"

fire() { g "TARGET='http://$SUBJECT_IP:8091$3' ARM='$4' RATE=$1 DURATION=$2 CONNECTIONS=200 \
     BODY='$BODY' SIGNATURE='$SIG' k6 run --quiet /tmp/pgo-ingest.js" > "$5" 2>&1; }
delivered() { grep -oE 'http_reqs[.[:space:]]*:[[:space:]]*[0-9]+[[:space:]]+[0-9.]+/s' "$1" | grep -oE '[0-9.]+/s' | tr -d '/s'; }
p50() { grep -oE 'p\(50\)=[0-9.]+[a-zµ]*' "$1" | head -1 | cut -d= -f2; }

echo "=== seeding: ingest at $SEED_RATE rps for ${SEED_SECONDS}s ==="
fire "$SEED_RATE" "${SEED_SECONDS}s" "/hooks/$ENDPOINT" ingest "$OUT/raw/seed.log"
# The subject host has no sqlite3, and reading a live WAL database from outside the process that
# owns it is a bad idea anyway. The service counts its own rows.
echo "  seeded rows (via /api/events): $(s "curl -s --max-time 5 'http://127.0.0.1:8091/api/events?limit=1' | grep -oE '\"total\"[: ]*[0-9]+' | grep -oE '[0-9]+$' || echo unknown")"
echo "  db on disk: $(s "du -sh /root/b17-run/a.db 2>/dev/null | cut -f1")"
sleep 20

# Knees are kept in a file rather than an associative array, so this runs on the bash that is
# actually here rather than the one the author assumed.
KNEEFILE=$(mktemp)
knee_set() { printf '%s %s\n' "$1" "$2" >> "$KNEEFILE"; }
knee_get() { awk -v k="$1" '$1==k{v=$2} END{print (v==""?0:v)}' "$KNEEFILE"; }
sweep() {
  local name=$1 arm=$2 path=$3; shift 3
  echo "=== saturation sweep: $name ==="
  local prev=0
  for r in "$@"; do
    fire "$r" 15s "$path" "$arm" "$OUT/raw/sweep-$name-$r.log"
    local d p; d=$(delivered "$OUT/raw/sweep-$name-$r.log"); p=$(p50 "$OUT/raw/sweep-$name-$r.log")
    printf "  offered %5s -> delivered %-10s p50 %-9s" "$r" "${d:-?}" "${p:-?}"
    if awk -v d="${d:-0}" -v r="$r" 'BEGIN{exit !(d < r*0.97)}'; then
      echo "  <- KNEE"; knee_set "$name" "$prev"; sleep 12; return
    fi
    echo; prev=$r; sleep 12
  done
  knee_set "$name" "$prev"
  echo "  (no knee found up to $prev - the ladder is too short, and that is a result)"
}
sweep health    control "/health/live"     400 800 1600 2400 3200
sweep ingest    ingest  "/hooks/$ENDPOINT" 100 200 300 400
sweep apievents control "/api/events"      100 200 300 400
sweep journal   control "/journal"          20  40  60  80

measure() {
  local name=$1 arm=$2 path=$3
  local knee rate; knee=$(knee_get "$name")
  rate=$(awk -v k="$knee" 'BEGIN{printf "%d", k*0.6}'); [ "$rate" -lt 10 ] && rate=10
  echo "=== $name: knee ${knee}, measuring at $rate rps (60 % of it) ==="
  g "setsid nohup env TARGET='http://$SUBJECT_IP:8091$path' ARM='$arm' RATE=$rate DURATION=50s \
     CONNECTIONS=200 BODY='$BODY' SIGNATURE='$SIG' k6 run --quiet /tmp/pgo-ingest.js \
     > /tmp/k6-$name.log 2>&1 </dev/null & disown -a; true" >/dev/null
  sleep 4
  s "perf record -q -g -e cpu-clock -F 999 -o /tmp/c2-$name.data -p $PID -- sleep 35" 2>&1 | tail -1
  s "perf script -i /tmp/c2-$name.data -F ip,sym,dso 2>/dev/null" | gzip -9 > "$OUT/raw/$name-fp-stacks.txt.gz"
  sleep 8
  g "grep -E 'http_reqs|dropped_iterations|p\(50\)=' /tmp/k6-$name.log | head -3" > "$OUT/raw/$name-k6.txt" 2>&1
  sed 's/^/    /' "$OUT/raw/$name-k6.txt"
  sleep 15
  g "setsid nohup env TARGET='http://$SUBJECT_IP:8091$path' ARM='$arm' RATE=$rate DURATION=45s \
     CONNECTIONS=200 BODY='$BODY' SIGNATURE='$SIG' k6 run --quiet /tmp/pgo-ingest.js \
     > /tmp/k6d-$name.log 2>&1 </dev/null & disown -a; true" >/dev/null
  sleep 4
  s "perf record -q --call-graph dwarf,2048 -e cpu-clock -F 199 -o /tmp/c2d-$name.data -p $PID -- sleep 30" 2>&1 | tail -1
  s "perf script -i /tmp/c2d-$name.data -F ip,sym,dso 2>/dev/null" | gzip -9 > "$OUT/raw/$name-dwarf-stacks.txt.gz"
  echo "    fp $(du -h "$OUT/raw/$name-fp-stacks.txt.gz" | cut -f1)  dwarf $(du -h "$OUT/raw/$name-dwarf-stacks.txt.gz" | cut -f1)"
  sleep 15
}
measure health    control "/health/live"
measure ingest    ingest  "/hooks/$ENDPOINT"
measure apievents control "/api/events"
measure journal   control "/journal"

printf 'endpoint,knee,rate\n' > "$OUT/rates.csv"
for k in health ingest apievents journal; do
  v=$(knee_get "$k")
  printf '%s,%s,%d\n' "$k" "$v" "$(awk -v v="$v" 'BEGIN{printf "%d", v*0.6}')" >> "$OUT/rates.csv"
done
column -t -s, "$OUT/rates.csv"
s "pkill -x $BINARY"
echo done
