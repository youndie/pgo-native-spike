#!/usr/bin/env bash
# THE RULER: A0 against itself, in µs of CPU per request, on the two-host stand.
#
#   SUBJECT=bench-a GENERATOR=bench-b SUBJECT_IP=10.0.0.2 bench/ruler.sh [--rate N] [--rounds 5]
#   ... bench/ruler.sh --ceiling          # the generator's own ceiling, before any arm is read
#   ... bench/ruler.sh --control          # the same binary under a concurrent load; must land OUTSIDE
#
# WHY TWO COPIES OF ONE BINARY AND NOT ONE PROCESS MEASURED FIVE TIMES. The brief says "the same
# binary, interleaved". Five rounds of a single arm would give the round-to-round spread and miss
# everything a real A/B adds: arm order, port, page cache, which copy started first. The ruler has
# to be produced by the machinery that will later be asked to attribute a difference to a compiler,
# so both arms here are the *same file* started twice, and any difference between them is the
# instrument talking about itself.
#
# THE UNIT IS AMENDMENT A1.1's. `utime+stime` from /proc/<pid>/stat is recorded, and so is the
# machine's own busy time from /proc/stat — the estimate that is bounded above by physics (four
# cores cannot deliver more than four seconds of CPU per second) and converges with the truth at
# saturation. The JIT phase measured the per-process tick counter overstating by 6.4–7.2 % and said
# to prefer the bounded one; this is that, adapted: the subject box is otherwise idle and both arms
# are single processes, so "the machine" is the subject plus noise, and the noise is measured
# rather than assumed — the IDLE arm's own CPU over the same window is reported beside it.
#
# WHAT THIS REFUSES, each one somebody's mistake already:
#   * it will not run the generator on the subject — they are separate ssh destinations, no default;
#   * it discards round 1 as warm-up, declared here rather than after seeing the numbers;
#   * it fails the run when k6 reports dropped_iterations — an open-model generator that could not
#     keep up has measured itself;
#   * it records `nproc` as the subject's runtime sees it with every round, because the same four
#     cores as a quota and as a cpuset differ by up to ninety times on this stack;
#   * it checks the offered/delivered/dropped arithmetic closes, and says so per round.
set -uo pipefail

RATE=${RATE:-400}
DURATION=${DURATION:-30s}
ROUNDS=${ROUNDS:-5}
CONNECTIONS=${CONNECTIONS:-200}
SETTLE=${SETTLE:-20}
MODE=ruler
SUBJECT=${SUBJECT:?set SUBJECT to the ssh destination of the host under test}
GENERATOR=${GENERATOR:?set GENERATOR to the ssh destination of the load generator}
SUBJECT_IP=${SUBJECT_IP:?set SUBJECT_IP to the address the generator reaches the subject on}
BINARY=${BINARY:-xyk-pagedoff}
SECRET=bench-secret
ENDPOINT=hook-1
OUT=${OUT:-logs/b-03}

while [ $# -gt 0 ]; do
  case "$1" in
    --rate) RATE=$2; shift 2 ;;
    --duration) DURATION=$2; shift 2 ;;
    --rounds) ROUNDS=$2; shift 2 ;;
    --ceiling) MODE=ceiling; shift ;;
    --control) MODE=control; shift ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

# ssh multiplexing, because the CPU brackets are taken around the k6 window and a fresh ssh
# handshake inside the bracket would be charged to the subject as measurement overhead.
CTL=/tmp/pgo-ruler-%r@%h:%p
SSHMUX=(-o ControlMaster=auto -o "ControlPath=$CTL" -o ControlPersist=120 -o BatchMode=yes)
# `-n` on ssh only: it detaches stdin, which is what stops a backgrounded remote server from
# holding the session open. scp has no such flag, so it gets the multiplexing options alone.
SSHOPT=(-n "${SSHMUX[@]}")
s() { ssh "${SSHOPT[@]}" "$SUBJECT" "$@"; }
g() { ssh "${SSHOPT[@]}" "$GENERATOR" "$@"; }

mkdir -p "$OUT/raw"
BODY='{"zen":"Non-blocking is better than blocking."}'
SIGNATURE=$(printf %s "$BODY" | openssl dgst -sha256 -hmac "$SECRET" -hex | sed 's/.*= //')

cleanup() { s "pkill -x $BINARY; pkill -f '[r]uler-hog'" >/dev/null 2>&1 || true; }
trap cleanup EXIT

echo "=== starting two copies of the SAME binary ($BINARY) on $SUBJECT ==="
# WAIT FOR THE PORTS, not for the processes. xyk's own B-20 recorded this: the binary died on
# start six times out of twelve, strictly alternating, every time a previous instance still held
# the port — EADDRINUSE, reported by the binary as "nothing was started and nothing was served".
# `pkill` returns as soon as the signal is sent, and the listener outlives it.
s "pkill -x $BINARY 2>/dev/null
for i in \$(seq 1 60); do
  ss -ltnH 'sport = :8091 or sport = :8092' | grep -q . || break
  sleep 1
done
rm -rf /root/ruler-run; mkdir -p /root/ruler-run; cd /root
export XYK_BOOTSTRAP_ENDPOINT_ID=$ENDPOINT XYK_BOOTSTRAP_SECRET=$SECRET XYK_BOOTSTRAP_SUBSCRIBERS=https://sink.invalid/a
XYK_DB_PATH=/root/ruler-run/a.db XYK_PORT=8091 setsid nohup ./$BINARY > /root/ruler-run/a.log 2>&1 < /dev/null &
XYK_DB_PATH=/root/ruler-run/b.db XYK_PORT=8092 setsid nohup ./$BINARY > /root/ruler-run/b.log 2>&1 < /dev/null &
disown -a
for i in \$(seq 1 60); do sleep 0.5
  curl -sf -o /dev/null http://127.0.0.1:8091/health/ready && curl -sf -o /dev/null http://127.0.0.1:8092/health/ready && { echo ready; exit 0; }
done
echo 'an arm never became ready' >&2; tail -3 /root/ruler-run/*.log >&2; exit 2" || exit 2

PID_A=$(s "ss -lptnH 'sport = :8091' | grep -oE 'pid=[0-9]+' | head -1 | cut -d= -f2")
PID_B=$(s "ss -lptnH 'sport = :8092' | grep -oE 'pid=[0-9]+' | head -1 | cut -d= -f2")
CLK=$(s 'getconf CLK_TCK')
NPROC=$(s "taskset -c -p $PID_A >/dev/null 2>&1; nproc")
echo "  arm a pid=$PID_A   arm b pid=$PID_B   CLK_TCK=$CLK   subject nproc=$NPROC"

# One snapshot line: process ticks for both arms, then the machine's own counters.
snap() { s "awk '{print \$14, \$15}' /proc/$PID_A/stat; awk '{print \$14, \$15}' /proc/$PID_B/stat; head -1 /proc/stat; date +%s.%N"; }

# IS THE SUBJECT IDLE? Asked instantaneously, and that is the whole point of this function's
# second version. The first read the ONE-MINUTE LOAD AVERAGE and required it below 0.5 - a
# threshold a run like this one can never reach, because each round leaves the box at ~1.5 busy
# cores and the average needs minutes to decay. So the gate never opened: it waited its full 150
# seconds, printed nothing, and proceeded anyway through `|| true`. A check that always times out
# and then continues is not a check, it is a delay - and worse than a delay here, because a round
# that starts on the tail of the previous one charges that tail to the arm being measured.
#
# Instantaneous busy from /proc/stat over a two-second window: below half a core means the
# previous round has actually drained, and it becomes true within seconds rather than minutes.
wait_until_idle() {
  # THIRD VERSION, and the second failure is the instructive one. Version two summed /proc/stat by
  # fixed field positions - 2..9 for the first snapshot and 11..18 for the second - on the
  # assumption of eight numeric columns. Linux prints ten. So every field index was wrong, the
  # delta came out non-positive, the sentinel fired, and the gate reported "busy 9 cores" sixty
  # times in a row before giving up. It did not report nothing: it reported a number no four-core
  # box can produce, and a four-core box claiming nine busy cores is the check telling you it is
  # broken. Both earlier versions then proceeded anyway through `|| true`, which is what let a
  # broken gate look like a working one twice.
  #
  # This version does the arithmetic where the file is, over however many columns there are.
  for _ in $(seq 1 60); do
    local busy
    busy=$(s "awk '/^cpu /{t=0; for(i=2;i<=NF;i++) t+=\$i; print t, \$5+\$6}' /proc/stat
              sleep 2
              awk '/^cpu /{t=0; for(i=2;i<=NF;i++) t+=\$i; print t, \$5+\$6}' /proc/stat" \
            | awk 'NR==1{t1=$1;i1=$2} NR==2{t2=$1;i2=$2}
                   END{ d=t2-t1; if(d<=0){print "nan"; exit} print (d-(i2-i1))/d*'"$NPROC"' }')
    case "$busy" in nan|"") echo "  idle check produced no number" >&2; return 1 ;; esac
    awk -v b="$busy" 'BEGIN{exit !(b<0.5)}' && return 0
  done
  echo "  subject never went idle (busy ${busy:-?} cores of $NPROC)" >&2; return 1
}

run_arm() {
  local arm=$1 round=$2 port url extra=${3:-}
  case "$arm" in a) port=8091 ;; b) port=8092 ;; esac
  url="http://$SUBJECT_IP:$port/hooks/$ENDPOINT"
  wait_until_idle || true

  local before after log
  log="$OUT/raw/$MODE-$arm-round$round.log"
  before=$(snap)
  g "TARGET='$url' ARM='$arm' RATE=$RATE DURATION=$DURATION CONNECTIONS=$CONNECTIONS \
     BODY='$BODY' SIGNATURE='$SIGNATURE' k6 run --quiet /tmp/pgo-ingest.js" > "$log" 2>&1
  after=$(snap)

  python3 scripts/ruler_row.py "$arm" "$round" "$CLK" "$NPROC" "$MODE" "$log" "$RATE" "$DURATION" \
    <<<"$before
--
$after" >> "$OUT/$MODE.csv"
  tail -1 "$OUT/$MODE.csv" | sed 's/^/  /'
  sleep "$SETTLE"
}

scp -q "${SSHMUX[@]}" bench/ingest.js "$GENERATOR:/tmp/pgo-ingest.js" || exit 2

case "$MODE" in
ceiling)
  # TWO SWEEPS, because the first attempt at this conflated them and produced a plateau at 400 rps
  # that was neither host's ceiling.
  #
  #   1. THE GENERATOR's. It must be asked UNPOOLED. Under `constant-arrival-rate` a VU is held for
  #      the whole round trip, so a pool of N cannot offer more than N/latency however fast the
  #      generator is: at the 490 ms the subject showed, 200 VUs cap the offered rate at ~408, and
  #      that is exactly the "ceiling" the first run reported. `ingest.js` documents this at length
  #      and the first run walked into it anyway.
  #   2. THE SUBJECT's knee, at the criterion's pool of 200, on the real endpoint. This is the one
  #      that picks the ruler's rate: a ruler taken on a saturated subject measures the saturation.
  #
  # And the arm name is load-bearing: `ingest.js` sends GET only when ARM=control. The first run
  # POSTed to /health/live, got a non-200 for every request, and reported 100% failed while still
  # printing a rate - a number off an error path, which is cheap and therefore flattering.
  echo "rate,arm,vus,rps,p50,p99,dropped,failed" > "$OUT/ceiling.csv"
  sweep() {
    local label=$1 armname=$2 vus=$3 url=$4; shift 4
    echo "=== $label ==="
    for r in "$@"; do
      wait_until_idle || true
      g "TARGET='$url' ARM='$armname' VUS=$vus RATE=$r DURATION=15s CONNECTIONS=$CONNECTIONS \
         BODY='$BODY' SIGNATURE='$SIGNATURE' k6 run --quiet /tmp/pgo-ingest.js" \
         > "$OUT/raw/ceiling-$label-$r.log" 2>&1
      printf '%s,%s,%s,%s\n' "$r" "$armname" "$vus" \
        "$(python3 scripts/ruler_ceiling.py "$r" "$OUT/raw/ceiling-$label-$r.log" | cut -d, -f2-)" \
        >> "$OUT/ceiling.csv"
      tail -1 "$OUT/ceiling.csv" | sed 's/^/  /'
      sleep 8
    done
  }
  sweep generator control 8000 "http://$SUBJECT_IP:8091/health/live" 2000 8000 16000
  sweep subject ingest 200 "http://$SUBJECT_IP:8091/hooks/$ENDPOINT" 100 200 300 400 600
  column -t -s, "$OUT/ceiling.csv"
  ;;
control)
  echo "=== POSITIVE CONTROL: arm b runs under a concurrent load; it must land OUTSIDE the ruler ==="
  echo "arm,round,rps,p50,p99,dropped,failed,responses,offered,accounting,proc_cpu_s,idle_arm_cpu_s,machine_busy_s,us_proc,us_machine,nproc,wall_s" > "$OUT/control.csv"
  for round in 1 2 3; do
    run_arm a "$round"
    s "setsid nohup bash -c 'exec -a ruler-hog bash -c \"while :; do :; done\"' >/dev/null 2>&1 </dev/null & setsid nohup bash -c 'exec -a ruler-hog bash -c \"while :; do :; done\"' >/dev/null 2>&1 </dev/null & disown -a" >/dev/null 2>&1
    sleep 2
    run_arm b "$round"
    s "pkill -f '[r]uler-hog'" >/dev/null 2>&1
    sleep 5
  done
  column -t -s, "$OUT/control.csv"
  ;;
ruler)
  echo "=== $ROUNDS rounds at $RATE rps, the same binary as both arms, interleaved, round 1 discarded ==="
  echo "arm,round,rps,p50,p99,dropped,failed,responses,offered,accounting,proc_cpu_s,idle_arm_cpu_s,machine_busy_s,us_proc,us_machine,nproc,wall_s" > "$OUT/ruler.csv"
  for round in $(seq 1 "$ROUNDS"); do
    for arm in a b; do run_arm "$arm" "$round"; done
  done
  column -t -s, "$OUT/ruler.csv"
  ;;
esac

{
  echo "subject:   $(s 'hostname; nproc; ldd --version | head -1' | tr '\n' ' ')"
  echo "generator: $(g 'hostname; nproc; k6 version' | tr '\n' ' ')"
  echo "binary:    $BINARY  $(s "stat -c '%s bytes, mtime %y' /root/$BINARY")"
  echo "mode: $MODE  rate: $RATE  duration: $DURATION  rounds: $ROUNDS  connections: $CONNECTIONS"
} | tee "$OUT/raw/$MODE-hosts.txt"
