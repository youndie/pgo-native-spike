#!/usr/bin/env python3
"""How much of a profile actually reached the module — RQ0's two numbers.

RQ0's green condition is not "a profile was produced". It is how many functions with non-zero
counts had the profile applied, and how many were dropped on a hash mismatch. Those are different
numbers from "functions in the profile" and "annotated defines", which is what the first version
of the results document reported.

    llvm-profdata show -all-functions -counts i.profdata > show-all.txt
    llvm-dis -o applied.ll applied.bc
    scripts/profile_applied.py show-all.txt applied.ll

Two traps this encodes, both hit while writing it:
  * Kotlin mangled names contain '(', '#' and '{}', so they are emitted as QUOTED LLVM symbols.
    A define regex that stops at the first '(' truncates every Kotlin name and reports the whole
    program as missing from its own module.
  * PGO prefixes internal-linkage symbols with "<module>;" in the profile, so a name-for-name
    comparison counts them as dropped when they were applied.
"""
import re
import sys

DEF = re.compile(r'^define\b[^@\n]*@(?:"([^"]*)"|([A-Za-z0-9_.$]+))\s*\(')
ENTRY_COUNT = re.compile(r'^(![0-9]+) = !\{!"function_entry_count", i64 \d+\}', re.M)


def read_profile(path):
    """name -> (hash, has_a_non_zero_counter)."""
    out, name = {}, None
    for line in open(path, encoding="utf-8", errors="replace"):
        m = re.match(r"^  (\S.*):$", line)
        if m:
            name = m.group(1)
            continue
        m = re.match(r"^    Hash: (\S+)", line)
        if m and name:
            out[name] = [m.group(1), False]
            continue
        m = re.match(r"^    Block counts: \[(.*)\]", line)
        if m and name in out:
            out[name][1] = any(int(x) > 0 for x in m.group(1).split(",") if x.strip())
    return out


def read_module(path):
    """(every define name, the ones carrying a function_entry_count)."""
    text = open(path, encoding="utf-8", errors="replace").read()
    counts = set(ENTRY_COUNT.findall(text))
    every, annotated = set(), set()
    for line in re.findall(r"^define\b.*$", text, re.M):
        m = DEF.match(line)
        if not m:
            continue
        name = m.group(1) or m.group(2)
        every.add(name)
        prof = re.search(r"!prof (![0-9]+)", line)
        if prof and prof.group(1) in counts:
            annotated.add(name)
    return every, annotated


def bare(name):
    """Strip the "<module>;" prefix PGO puts on internal-linkage symbols."""
    return name.split(";", 1)[1] if ";" in name else name


def report(profile_path, module_path):
    profile = read_profile(profile_path)
    every, annotated = read_module(module_path)
    if not every:
        sys.exit(f"parsed no defines out of {module_path} - the reader is broken, not the module")
    if not profile:
        sys.exit(f"parsed no functions out of {profile_path}")

    non_zero = {n for n, (_, nz) in profile.items() if nz}
    applied = {n for n in non_zero if n in annotated or bare(n) in annotated}
    dropped = sorted(non_zero - applied)
    # A name in the profile that is not a define anywhere is not a hash mismatch: the function was
    # inlined away or never emitted. Only a name that IS still a define was offered and refused.
    mismatch = [n for n in dropped if n in every or bare(n) in every]
    absent = [n for n in dropped if n not in every and bare(n) not in every]

    print(f"defines in the module:                 {len(every)}")
    print(f"functions in the profile:              {len(profile)}")
    print(f"... with a non-zero counter:           {len(non_zero)}")
    print(f"... of those, profile applied:         {len(applied)}")
    print(f"... of those, dropped:                 {len(dropped)}")
    print(f"      still a define -> hash mismatch: {len(mismatch)}")
    print(f"      no longer a define -> inlined or not emitted: {len(absent)}")
    for n in mismatch[:10]:
        print(f"        mismatch: {n[:100]}")
    for n in absent[:10]:
        print(f"        absent:   {n[:100]}")
    return len(non_zero), len(applied), len(mismatch)


def control():
    """The reader must find Kotlin names, and must not count a prefixed local as dropped."""
    import tempfile, os
    ll = '''define i64 @"kfun:S1#area(kotlin.Long){}kotlin.Long"(i64 %0) !prof !1 {
  ret i64 %0
}
define internal void @helper() !prof !1 {
  ret void
}
define void @plain_c_function() !prof !1 {
  ret void
}
define void @"kfun:#gone(){}"() {
  ret void
}
!1 = !{!"function_entry_count", i64 7}
'''
    prof = '''Counters:
  kfun:S1#area(kotlin.Long){}kotlin.Long:
    Hash: 0x1
    Counters: 1
    Block counts: [7]
  out;helper:
    Hash: 0x2
    Counters: 1
    Block counts: [7]
  plain_c_function:
    Hash: 0x3
    Counters: 1
    Block counts: [7]
  kfun:#never_inlined(){}:
    Hash: 0x4
    Counters: 1
    Block counts: [7]
'''
    d = tempfile.mkdtemp()
    pp, mp = os.path.join(d, "p.txt"), os.path.join(d, "m.ll")
    open(pp, "w").write(prof)
    open(mp, "w").write(ll)
    every, annotated = read_module(mp)
    ok = True

    def check(label, got, want):
        nonlocal ok
        status = "ok  " if got == want else "FAIL"
        if got != want:
            ok = False
        print(f"  {status} {label}: got {got}, want {want}")

    # A quoted Kotlin name survives the parser whole, parentheses and all.
    check("Kotlin name parsed whole", "kfun:S1#area(kotlin.Long){}kotlin.Long" in every, True)
    check("unquoted C name parsed", "plain_c_function" in every, True)
    check("C name with !prof is annotated", "plain_c_function" in annotated, True)
    n, applied, mismatch = report(pp, mp)
    # helper is "out;helper" in the profile and "helper" in the module: applied, not dropped.
    check("prefixed local counted as applied", applied, 3)
    # never_inlined has a non-zero count and is not a define: absent, not a hash mismatch.
    check("function absent from module is not a mismatch", mismatch, 0)
    return ok


if __name__ == "__main__":
    if len(sys.argv) == 2 and sys.argv[1] == "--control":
        print("control for scripts/profile_applied.py")
        sys.exit(0 if control() else 1)
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    report(sys.argv[1], sys.argv[2])
