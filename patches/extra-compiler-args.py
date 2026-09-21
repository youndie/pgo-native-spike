#!/usr/bin/env python3
"""Add `xyk.extraCompilerArgs` to a COPY of xyk that predates B-19.

    patches/extra-compiler-args.py <path-to-a-copy-of-xyk>

B-19 added this property upstream, so revisions from 6359a88 onward need nothing. Older ones
silently ignore `-Pxyk.extraCompilerArgs` — Gradle does not complain about an unknown project
property, the build succeeds, and the flags never reach the compiler. That is how the first
attempt at B-24's profile-drift measurement produced three builds and no IR.

The edit adds a property and appends it to `freeCompilerArgs`. Unset, it appends an empty list,
so a build that passes nothing is the build that revision always produced.
"""
import sys
from pathlib import Path

root = Path(sys.argv[1]) if len(sys.argv) > 1 else sys.exit(__doc__)
f = root / "server" / "build.gradle.kts"
s = f.read_text()
if "xyk.extraCompilerArgs" in s:
    print(f"{root.name}: already has it")
    sys.exit(0)

anchor = "                if (staticLinux) {"
if anchor not in s:
    sys.exit(f"{f}: no `if (staticLinux) {{` to insert before")

decl = '''val extraCompilerArgs =
    (project.findProperty("xyk.extraCompilerArgs") as String?)
        ?.split(" ")
        ?.filter { it.isNotBlank() }
        .orEmpty()

'''
# Before the first `kotlin {` block so it is in scope inside the target configuration.
k = s.index("kotlin {")
s = s[:k] + decl + s[k:]
s = s.replace(anchor, "                freeCompilerArgs += extraCompilerArgs\n\n" + anchor, 1)
f.write_text(s)
print(f"{root.name}: patched")
