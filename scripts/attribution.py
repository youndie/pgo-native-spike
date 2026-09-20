#!/usr/bin/env python3
"""The RQ1 attribution grammar: one leaf frame in, exactly one bucket out.

Written as a script rather than a pipeline of greps because the pipeline version made the same
mistake twice, once in B-02 and once in B-06: `k[a-z]+:` matches `kotlin::`, the C++ namespace, so
the Kotlin-data-prefix bucket and the runtime bucket came out with identical counts. Identical
counts in two buckets that share no symbols is the tell, and it is only visible if both are
printed.

The rules are ordered and the first match wins, so every frame lands in exactly one row and the
rows add up to the input. The order is not arbitrary: `kotlin::` is tested BEFORE the Kotlin
prefixes, because that is the pair that collides.
"""
import re
import sys
from collections import Counter

# The eight prefixes this subject's symbol table actually carries. Named rather than matched by
# pattern, so a new prefix in a future Kotlin release shows up as `other` and is noticed instead
# of being silently absorbed.
KOTLIN_PREFIXES = ("kfun:", "kclass:", "kifacevtable:", "kifacetable:",
                   "krefs:", "kintf:", "kvar:", "kassociatedobjects:")

RUST_CRATES = ("sqlx", "tokio", "core::", "alloc::", "std::", "hashbrown", "libsqlite3")


def bucket(sym, dso):
    if "kernel.kallsyms" in dso:
        return "kernel"
    if "[vdso]" in dso or "[vdso]" in sym:
        return "vdso"
    if not sym or sym == "[unknown]":
        return "unresolved"
    # The leading underscore is Mach-O's, and it is stripped ONLY for the Kotlin prefix test.
    # Stripping it before the mangled-name tests made `_ZN6kotlin` and `_R` unreachable, so the
    # entire C++ runtime and all of Rust fell through to "libc and other native" - and the table
    # still reconciled, still totalled, and still looked like a measurement. The control caught it;
    # no aggregate check could have.
    unpre = sym[1:] if sym.startswith("_") else sym
    # BEFORE the Kotlin prefixes. `kotlin::` is the C++ runtime's namespace and `kotlin:` is not a
    # Kotlin symbol prefix; a pattern that cannot tell them apart reports one as the other.
    if sym.startswith("_ZN6kotlin") or unpre.startswith("kotlin::") or unpre.startswith("Kotlin_"):
        return "runtime"
    for p in KOTLIN_PREFIXES:
        if unpre.startswith(p):
            return "kotlin:" + p.rstrip(":")
    if sym.startswith("_R") or any(unpre.startswith(c) for c in RUST_CRATES):
        return "rust"
    if sym.startswith("_Z"):
        return "cxx-other"
    return "libc-and-other-native"


def main():
    counts = Counter()
    examples = {}
    total = 0
    for line in open(sys.argv[1], encoding="utf-8", errors="replace"):
        parts = line.split(None, 2)
        if len(parts) < 2:
            continue
        sym = parts[1]
        dso = parts[2] if len(parts) > 2 else ""
        b = bucket(sym, dso)
        counts[b] += 1
        examples.setdefault(b, sym)
        total += 1

    print(f"{'bucket':28} {'samples':>8} {'share':>7}   first symbol seen")
    for b, n in counts.most_common():
        print(f"{b:28} {n:8d} {100*n/total:6.2f}%   {examples[b][:58]}")
    print(f"{'TOTAL':28} {total:8d} {100.0:6.2f}%")
    print(f"\nreconciles: {sum(counts.values()) == total}")


if __name__ == "__main__":
    main()
