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
import gzip
import sys
from collections import Counter

# The eight prefixes this subject's symbol table actually carries. Named rather than matched by
# pattern, so a new prefix in a future Kotlin release shows up as `other` and is noticed instead
# of being silently absorbed.
KOTLIN_PREFIXES = ("kfun:", "kclass:", "kifacevtable:", "kifacetable:",
                   "krefs:", "kintf:", "kvar:", "kassociatedobjects:")

RUST_CRATES = ("sqlx", "tokio", "core::", "alloc::", "std::", "hashbrown", "libsqlite3")

LINE = re.compile(r"^\s*[0-9a-fA-F]+\s+(?P<sym>.*?)\s*\((?P<dso>[^()]*)\)\s*$")


def parse_line(line):
    """One `perf script -F ip,sym,dso` line -> (symbol, dso), or None.

    Split on whitespace and the second field is the symbol - except that perf DEMANGLES, and a
    demangled C++ name contains spaces. `void kotlin::gc::internal::MainGCThread<...>::PerformFullGC(long)`
    split that way yields the symbol `void`, which matches no rule and lands in
    "libc and other native". That silently moved a tenth of the samples out of the runtime bucket
    and into libc, and the table still reconciled because every frame still landed somewhere.

    The dso is the last parenthesised group on the line, so the symbol is everything between the
    address and it.
    """
    m = LINE.match(line)
    if not m:
        return None
    return m.group("sym"), m.group("dso")



def _open(path):
    """Raw perf output is stored gzipped: 284 MB of call graphs is 3 MB compressed, and a log
    nobody can commit is a log nobody keeps."""
    if path.endswith(".gz"):
        return gzip.open(path, "rt", encoding="utf-8", errors="replace")
    return _open(path)


def significant(sym):
    """Strip a C++ return type so the name the rules test is the qualified name.

    perf demangles, and a demangled C++ signature is `<return type> <qualified::name>(<args>)`.
    `void kotlin::gc::...::PerformFullGC(long)` therefore does not *start with* `kotlin::`, and a
    rule written as `startswith` misses the entire GC thread - about a tenth of the samples on
    this subject - and drops it into "libc and other native" instead. Templates make it worse:
    the return type can itself be `std::unique_ptr<...>`.

    The qualified name is the last space-separated token before the argument list, so that is what
    is returned. A plain C symbol has no spaces and comes back unchanged.
    """
    head = sym.split("(", 1)[0]
    if " " not in head:
        return sym
    return head.rsplit(" ", 1)[-1] + sym[len(head):]


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
    sym = significant(sym)
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
    for line in _open(sys.argv[1]):
        got = parse_line(line)
        if got is None:
            continue
        sym, dso = got
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
