#!/usr/bin/env python3
"""RQ1's table for one endpoint: self buckets from the leaf, inclusive Kotlin from the stack.

`perf script -g` prints one blank-line-separated block per sample, leaf first and callers after.
So the SELF bucket is the first line of a block and nothing else; treating every line as a leaf
turns a call-graph profile into a different measurement that still produces a plausible table.

The inclusive column is the brief's own correction to itself: self attribution understates the
ceiling, because a sample in the allocator reached from Kotlin counts as runtime even though a
promoted and inlined call might have removed the allocation's cause. The brief requires a red RQ1
to be reported with this number beside it, so the reader can see what the self rule cost.
"""
import gzip
import sys
from collections import Counter

sys.path.insert(0, "scripts")
from attribution import bucket, parse_line  # noqa: E402


def _open(path):
    """Raw perf output is stored gzipped: 284 MB of call graphs is 3 MB compressed, and a log
    nobody can commit is a log nobody keeps."""
    if path.endswith(".gz"):
        return gzip.open(path, "rt", encoding="utf-8", errors="replace")
    return _open(path)


def stacks(path):
    block = []
    for line in _open(path):
        if not line.strip():
            if block:
                yield block
                block = []
            continue
        got = parse_line(line)
        if got is not None:
            block.append(got)
    if block:
        yield block


def main():
    self_counts, total, kotlin_anywhere, depth1 = Counter(), 0, 0, 0
    for st in stacks(sys.argv[1]):
        total += 1
        sym, dso = st[0]
        self_counts[bucket(sym, dso)] += 1
        if any(bucket(s, d).startswith("kotlin:") for s, d in st):
            kotlin_anywhere += 1
        if len(st) == 1:
            depth1 += 1

    name = sys.argv[2] if len(sys.argv) > 2 else sys.argv[1]
    print(f"== {name}   {total} samples")
    for b, n in self_counts.most_common():
        print(f"   {b:26} {n:7d} {100*n/total:6.2f}%")
    kfun = self_counts.get("kotlin:kfun", 0)
    print(f"   {'-'*26}")
    print(f"   {'KOTLIN self (the gate)':26} {kfun:7d} {100*kfun/total:6.2f}%")
    print(f"   {'Kotlin anywhere on stack':26} {kotlin_anywhere:7d} {100*kotlin_anywhere/total:6.2f}%")
    unres = self_counts.get("unresolved", 0)
    print(f"   {'unresolved':26} {unres:7d} {100*unres/total:6.2f}%"
          f"   {'<- ABOVE 5%, run not used' if 100*unres/total > 5 else ''}")
    print(f"   stacks of depth 1 (no callers recorded): {100*depth1/total:.1f}%")
    print(f"   reconciles: {sum(self_counts.values()) == total}")


if __name__ == "__main__":
    main()
