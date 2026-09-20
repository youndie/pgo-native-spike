#!/usr/bin/env python3
"""ns/op per arm with a 99 % interval, because the brief asks for non-overlapping ones.

The benchmark already takes the best of five inside one process. That is not an interval: it is
one number with the low tail selected, and it hides exactly the run-to-run variation the verdict
depends on. The unit control moved 11.6 % between two binaries that differ only in a profile,
which is impossible as a PGO effect and is the reason this script exists.

ARMS MUST BE INTERLEAVED, and the first version of the driver did not interleave them - it ran
all of A0's repeats and then all of A2's. The unit control caught it: `sum` on the uniform arm,
which performs no dispatch at all, showed a 31.5 % change with non-overlapping intervals. That is
not a thing a profile can do, so the run measured drift between two blocks of time rather than a
difference between two binaries. The whole study interleaves its macro arms for exactly this
reason; the micro half was written without it.

Input lines: "<mode> <arm> [round] <label> <ns> ns/op sink=<x>".
"""
import statistics as st
import sys
from collections import defaultdict

T99 = {2: 9.925, 3: 5.841, 4: 4.604, 5: 4.032, 6: 3.707, 7: 3.499, 8: 3.355, 9: 3.250}


def interval(xs):
    m = st.mean(xs)
    if len(xs) < 2:
        return m, 0.0
    return m, T99.get(len(xs) - 1, 3.0) * st.stdev(xs) / len(xs) ** 0.5


def main():
    data = defaultdict(list)
    for line in open(sys.argv[1], encoding="utf-8", errors="replace"):
        p = line.split()
        # the round number is optional, so find the ns/op marker rather than counting columns
        if "ns/op" not in p:
            continue
        i = p.index("ns/op")
        data[(p[0], p[1], p[i - 2])].append(float(p[i - 1]))

    # the unit control is checked FIRST, and a run whose control separates is void whatever the
    # other rows say
    for mode in sorted({k[0] for k in data}):
        a0 = data.get((mode, "a0", f"sum-{mode}"), [])
        a2 = data.get((mode, mode, f"sum-{mode}"), [])
        if a0 and a2:
            m0, c0 = interval(a0); m2, c2 = interval(a2)
            if (m0 - c0 > m2 + c2) or (m2 - c2 > m0 + c0):
                print(f"!! {mode}: the unit control separates "
                      f"({m0:.3f}+/-{c0:.3f} vs {m2:.3f}+/-{c2:.3f}, "
                      f"{100*(m2-m0)/m0:+.1f}%) - THIS MODE IS VOID\n")

    modes = sorted({k[0] for k in data})
    print(f"{'mode':9} {'measure':16} {'A0 ns/op':>18} {'A2 ns/op':>18} {'change':>9}  verdict")
    for mode in modes:
        labels = sorted({k[2] for k in data if k[0] == mode})
        for lab in labels:
            a0 = data.get((mode, "a0", lab), [])
            a2 = data.get((mode, mode, lab), [])
            if not a0 or not a2:
                continue
            m0, c0 = interval(a0)
            m2, c2 = interval(a2)
            change = 100 * (m2 - m0) / m0
            # non-overlapping 99 % intervals AND at least 10 %, which is the brief's own rule
            sep = (m0 - c0 > m2 + c2) or (m2 - c2 > m0 + c0)
            if not sep:
                v = "intervals overlap"
            elif abs(change) < 10:
                v = f"separated but under 10 %"
            else:
                v = "MET" if change < 0 else "MET (worse)"
            print(f"{mode:9} {lab:16} {m0:10.3f}+/-{c0:<6.3f} {m2:10.3f}+/-{c2:<6.3f} {change:+8.1f}%  {v}")
        print()


if __name__ == "__main__":
    main()
