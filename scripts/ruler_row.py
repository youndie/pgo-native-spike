#!/usr/bin/env python3
"""One CSV row per arm-round: k6's numbers, and CPU per request in both estimates.

The two estimates are amendment A1.1's. `proc` is utime+stime of the loaded arm from
/proc/<pid>/stat, which the JIT phase measured overstating by 6.4-7.2% on its host and, being a
tick sample, is not bounded by anything. `machine` is the subject's own busy time from /proc/stat
over the same bracket: it cannot exceed nproc seconds per second, and on an otherwise idle box it
is the subject plus whatever noise there was - which is why the IDLE arm's CPU over the same
window is in its own column. An idle arm that is not idle means the machine estimate is charging
this arm for the other one.
"""
import re
import sys


def ticks(line):
    a, b = line.split()
    return int(a) + int(b)


def cpu_line(line):
    # cpu  user nice system idle iowait irq softirq steal ...
    f = [int(x) for x in line.split()[1:]]
    idle = f[3] + (f[4] if len(f) > 4 else 0)
    return sum(f), idle


def main():
    arm, round_, clk, nproc, mode, log, rate, duration = sys.argv[1:9]
    clk = float(clk)
    before, after = sys.stdin.read().split("\n--\n")
    b, a = before.strip().split("\n"), after.strip().split("\n")

    proc_s = (ticks(a[0]) - ticks(b[0])) / clk if arm == "a" else (ticks(a[1]) - ticks(b[1])) / clk
    idle_s = (ticks(a[1]) - ticks(b[1])) / clk if arm == "a" else (ticks(a[0]) - ticks(b[0])) / clk
    tot_a, idl_a = cpu_line(a[2])
    tot_b, idl_b = cpu_line(b[2])
    machine_s = ((tot_a - tot_b) - (idl_a - idl_b)) / clk
    wall = float(a[3]) - float(b[3])

    text = open(log, encoding="utf-8", errors="replace").read()

    def grab(pat, default="?"):
        m = re.search(pat, text)
        return m.group(1) if m else default

    responses = grab(r"http_reqs[.\s]*:\s*(\d+)")
    rps = grab(r"http_reqs[.\s]*:\s*\d+\s+([0-9.]+)/s")
    p50 = grab(r"p\(50\)=([0-9.]+[a-zµ]*)")
    p99 = grab(r"p\(99\)=([0-9.]+[a-zµ]*)")
    dropped = grab(r"dropped_iterations[.\s]*:\s*(\d+)", "0")
    failed = grab(r"http_req_failed[.\s]*:\s*([0-9.]+%)")
    iters = grab(r"iterations[.\s]*:\s*(\d+)")

    # THE ACCOUNTING, and it has to be against what was OFFERED rather than against itself. The
    # first version of this compared responses with iterations, which is `abs(x - x)` once the
    # algebra is done and says "yes" to anything - a check that cannot fail is worse than no check,
    # because it is read as evidence. Offered is the open-model executor's own contract: rate times
    # duration. It must equal what came back plus what the generator admits it dropped.
    secs = float(re.sub(r"[^0-9.]", "", duration) or 0)
    if duration.endswith("m"):
        secs *= 60
    offered = int(round(float(rate) * secs))
    try:
        accounted = int(iters or responses) + int(dropped)
        closes = "yes" if abs(offered - accounted) <= max(5, offered // 100) else "MISSING %d" % (offered - accounted)
    except ValueError:
        closes = "?"

    def per_req(seconds):
        try:
            return "%.1f" % (seconds * 1e6 / int(responses))
        except (ValueError, ZeroDivisionError):
            return "?"

    print(",".join(str(x) for x in [
        arm, round_, rps, p50, p99, dropped, failed, responses, offered, closes,
        "%.2f" % proc_s, "%.2f" % idle_s, "%.2f" % machine_s,
        per_req(proc_s), per_req(machine_s), nproc, "%.1f" % wall,
    ]))


if __name__ == "__main__":
    main()
