import sys
p = "server/build.gradle.kts"
s = open(p, encoding="utf-8").read()
if "xyk.extraCompilerArgs" in s:
    print("  already patched"); sys.exit(0)
anchor = "                if (staticLinux) {"
assert anchor in s, "anchor not found"
add = '''                // ROUTE B NEEDS FLAGS THIS BUILD DOES NOT EXPOSE, and a study should not have
                // to edit a product's build file to pass a compiler argument.
                // `-Xsave-llvm-ir-after` dumps the linked pre-optimisation module and
                // `-Xcompile-from-bitcode` resumes from it. Proposed to xyk as B-19.
                (project.findProperty("xyk.extraCompilerArgs") as String?)
                    ?.split(" ")?.filter { it.isNotBlank() }
                    ?.forEach { freeCompilerArgs += it }
                (project.findProperty("xyk.extraLinkerArgs") as String?)
                    ?.split(" ")?.filter { it.isNotBlank() }
                    ?.let { linkerOpts(*it.toTypedArray()) }

''' + anchor
open(p, "w", encoding="utf-8").write(s.replace(anchor, add, 1))
print("  patched")
