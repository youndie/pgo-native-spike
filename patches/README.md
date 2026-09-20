# Patches

The brief's deliverable is "a working recipe in a fork ... and the patches themselves". There is
no fork ([B-04](../docs/backlog/B-04-fork-at-the-pinned-tag-and-the-baseline.md) — the stock
toolchain has everything), so the patch set is smaller than the brief expected: **one build-file
change to a copy of the subject, and one replaced object in a runtime archive.**

| Patch | What it does | Why it is not upstream |
|---|---|---|
| `apply-extra-compiler-args.py` | adds `xyk.extraCompilerArgs` and `xyk.extraLinkerArgs` properties to xyk's `server/build.gradle.kts`, so `-Xsave-llvm-ir-after` and `-Xcompile-from-bitcode` can reach the compiler | it is a change to a product repository made for a study's convenience; proposed as [B-19](../docs/backlog/B-19-stamp-the-commit-into-the-binary.md) rather than pushed. It is applied to the **rsync copy** on the build host, never to the repository |
| the profile-runtime archive | `libclang_rt.profile.a` with `InstrProfilingVersionVar.c.o` replaced by a one-line C file setting the IR-profile bit | see [B-08](../docs/backlog/B-08-rq0-a-merged-profile-applied.md). Without it the profile merges as front-end and `pgo-instr-use` refuses it; with the object simply deleted the link fails on an undefined hidden symbol |

Neither is a compiler patch. The brief anticipated a fork of `JetBrains/kotlin`; what the work
actually needed was two build-level changes and a set of stock `-X` flags.
