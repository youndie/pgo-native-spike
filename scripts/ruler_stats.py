#!/usr/bin/env python3
"""Reduce a ruler CSV to the numbers the verdict needs, and name which is which.

The brief says "the spread of that run is the ruler" and never says what spread means. Three
readings are defensible and they differ by an order of magnitude, so all three are printed and the
verdict names the one it used rather than picking silently.
"""
import csv
import statistics as st
import sys

T95 = {2: 4.303, 4: 2.776, 6: 2.447, 8: 2.306, 10: 2.228, 12: 2.179, 14: 2.145, 16: 2.120}


def main():
    for path in sys.argv[1:]:
        rows = [r for r in csv.DictReader(open(path)) if r["round"] != "1"]
        if not rows:
            print(path, "- no counted rounds"); continue
        print("==", path, f"({len(rows)} counted rounds, round 1 discarded)")
        for col, label in (("us_machine", "machine"), ("us_proc", "proc  ")):
            a = [float(r[col]) for r in rows if r["arm"] == "a"]
            b = [float(r[col]) for r in rows if r["arm"] == "b"]
            v = a + b
            m = st.mean(v)
            sa = st.stdev(a) if len(a) > 1 else 0.0
            sb = st.stdev(b) if len(b) > 1 else 0.0
            pooled = ((sa ** 2 + sb ** 2) / 2) ** 0.5
            se = pooled * (1 / len(a) + 1 / len(b)) ** 0.5
            df = len(a) + len(b) - 2
            ci = T95.get(df, 2.2) * se
            diff = abs(st.mean(a) - st.mean(b))
            print(f"  {label}  mean {m:7.0f}  a {st.mean(a):7.0f}  b {st.mean(b):7.0f}")
            print(f"          round range {100*(max(v)-min(v))/m:5.1f}%   "
                  f"observed A-vs-A {100*diff/m:5.2f}%   95% CI on the difference +/-{100*ci/m:4.1f}%")
        idle = [float(r["idle_arm_cpu_s"]) / float(r["machine_busy_s"]) for r in rows]
        print(f"  idle-arm contamination {100*min(idle):.1f}-{100*max(idle):.1f}%   "
              f"dropped {sum(int(r['dropped']) for r in rows)}   "
              f"accounting {'all close' if all(r['accounting']=='yes' for r in rows) else 'CHECK'}")


if __name__ == "__main__":
    main()
