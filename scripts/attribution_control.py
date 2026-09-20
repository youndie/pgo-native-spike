#!/usr/bin/env python3
"""The positive control for the attribution grammar, and it is not decoration.

A grammar that puts everything in one bucket satisfies every aggregate check: the rows still
reconcile, the total is still right, and the table still looks like a measurement. What it cannot
survive is being handed a symbol whose bucket was decided before the grammar ran.

The collision this exists to catch is real and was made twice in this repository: `k[a-z]+:`
matches `kotlin::`, so the Kotlin-data bucket and the C++ runtime bucket came out with identical
counts in both B-02 and B-06.
"""
import sys

from attribution import bucket, parse_line

CASES = [
    # symbol, dso, expected bucket, why this one
    ("finish_task_switch.isra.0", "[kernel.kallsyms]", "kernel", "a scheduler function"),
    ("kfun:io.github.youndie.xyk#main(){}", "xyk-pagedoff", "kotlin:kfun",
     "application code, the bucket RQ1's gate is about"),
    ("kfun:kotlinx.coroutines.DispatchedTask#run(){}", "xyk-pagedoff", "kotlin:kfun",
     "library Kotlin - RQ1 counts it as Kotlin, which is the whole point of the rule"),
    ("kclass:kotlin.Int", "xyk-pagedoff", "kotlin:kclass",
     "a Kotlin DATA prefix; it must not land in kfun and must not land in runtime"),
    ("kotlin::alloc::CustomAllocator::CreateObject", "xyk-pagedoff", "runtime",
     "THE COLLISION: demangled C++, and `kotlin:` is a prefix of `kotlin::`"),
    ("_ZN6kotlin5alloc15CustomAllocator12CreateObjectEPK8TypeInfo", "xyk-pagedoff", "runtime",
     "the same function still mangled, because perf demangles and razves does not"),
    ("Kotlin_processObjectInMark", "xyk-pagedoff", "runtime", "the runtime's C entry points"),
    ("tokio::runtime::task::raw::poll", "xyk-pagedoff", "rust", "sqlx4k's Rust, demangled"),
    ("_RNvNtCs1234_5tokio7runtime4poll", "xyk-pagedoff", "rust", "Rust v0 mangling, undemangled"),
    ("_int_malloc", "xyk-pagedoff", "libc-and-other-native",
     "glibc, inside the binary because it is statically linked"),
    ("[unknown]", "xyk-pagedoff", "unresolved", "the row the brief discards a run over"),
]


LINES = [
    # THE GAP THIS CLOSES: every case above hands `bucket()` a symbol that is already split out.
    # The line parser was never exercised, and it was wrong - a demangled C++ name has spaces in
    # it, so splitting on whitespace made the symbol `void`.
    ("     55f1b2 void kotlin::gc::internal::MainGCThread<kotlin::gc::internal::CmsGCTraits>::PerformFullGC(long) (xyk-pagedoff)",
     "runtime", "a demangled C++ name with a return type and spaces"),
    ("     4a1c20 kfun:io.ktor.server.routing.Route#handle(kotlin.Int; kotlin.String){} (xyk-pagedoff)",
     "kotlin:kfun", "a Kotlin signature with a space after the semicolon"),
    ("ffffffff981fe443 __handle_mm_fault ([kernel.kallsyms])", "kernel", "the plain case"),
]


def main():
    bad = 0
    for sym, dso, want, why in CASES:
        got = bucket(sym, dso)
        ok = got == want
        bad += not ok
        print(f"  {'ok  ' if ok else 'FAIL'}  {want:22} {'' if ok else '<- got ' + got:24} {why}")
    for line, want, why in LINES:
        got_pair = parse_line(line)
        got = bucket(*got_pair) if got_pair else "UNPARSED"
        ok = got == want
        bad += not ok
        print(f"  {'ok  ' if ok else 'FAIL'}  {want:22} {'' if ok else '<- got ' + got:24} {why}")
    n = len(CASES) + len(LINES)
    print(f"\n{n - bad}/{n} cases land where they were declared to")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.path.insert(0, "scripts")
    sys.exit(main())
