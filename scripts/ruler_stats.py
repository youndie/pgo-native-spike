#!/usr/bin/env python3
"""Reduce a ruler CSV to the numbers the verdict needs, and name which is which.

The brief says "the spread of that run is the ruler" and never says what spread means. Three
readings are defensible and they differ by an order of magnitude, so all three are printed and the
verdict names the one it used rather than picking silently.
"""
import csv
import statistics as st
import sys

T95 = {2: 4.303, 3: 3.182, 4: 2.776, 5: 2.571, 6: 2.447, 7: 2.365, 8: 2.306, 10: 2.228, 12: 2.179, 14: 2.145, 16: 2.120}

# The ruler, pooled from the four A-against-A runs of B-03: the standard deviation of one paired
# round difference, as a percentage of the run's mean. Everything a comparison claims is measured
# against this.
RULER_SD_PCT = 2.92


def verdict(paired_pct, n_pairs, ci_pct):
    """What a two-binary comparison is entitled to say.

    For an A-against-A run the paired mean estimates noise. For A-against-B it estimates the
    difference, and the only honest verdict is one of three: distinguishable, indistinguishable
    with a stated resolution, or too few rounds to say either. A difference inside the interval is
    NOT zero - it is "below resolution, effect under N %", which is the brief's own wording and
    the thing it insists is never reported as nothing.
    """
    if abs(paired_pct) > ci_pct:
        return f"DISTINGUISHABLE: {paired_pct:+.2f}% against a {ci_pct:.2f}% interval"
    return (f"below resolution: |effect| under {ci_pct:.2f}% "
            f"(observed {paired_pct:+.2f}%, {n_pairs} paired rounds) - not zero")



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
        # PAIRED, because that is what interleaving is for: a drift moves both arms of a round
        # together and cancels here, and does not cancel in a within-arm standard deviation.
        by = {}
        for r in rows:
            by.setdefault(r["round"], {})[r["arm"]] = float(r["us_machine"])
        d = [v["a"] - v["b"] for v in by.values() if "a" in v and "b" in v]
        if len(d) > 1:
            m = st.mean(float(r["us_machine"]) for r in rows)
            sd = st.stdev(d)
            ci = T95.get(len(d) - 1, 2.2) * sd / len(d) ** 0.5
            print(f"  paired  mean {100*st.mean(d)/m:+.2f}%   95% CI +/-{100*ci/m:.2f}%   "
                  f"({len(d)} pairs, per-round sd {100*sd/m:.2f}% vs the ruler's {RULER_SD_PCT}%)")
            print(f"  -> {verdict(100*st.mean(d)/m, len(d), 100*ci/m)}")
        contam = [r.get("contamination", "?") for r in rows]
        if any(c not in ("clean", "?") for c in contam):
            print(f"  !! CONTAMINATED rounds present: {sum(1 for c in contam if c not in ('clean','?'))}")
        idle = [float(r["idle_arm_cpu_s"]) / float(r["machine_busy_s"]) for r in rows]
        print(f"  idle-arm contamination {100*min(idle):.1f}-{100*max(idle):.1f}%   "
              f"dropped {sum(int(r['dropped']) for r in rows)}   "
              f"accounting {'all close' if all(r['accounting']=='yes' for r in rows) else 'CHECK'}")


if __name__ == "__main__":
    main()
