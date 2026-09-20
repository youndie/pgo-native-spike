# B-22 — the replayed link, and the wall behind it

`recipe/replay-link.sh`, run on the build box (`2026-09-20-replay-link.log`). Three results, and
the third is the one worth carrying.

## 1. The replay is exact

`-Xverbose-phases=Linker` prints the whole `ld.lld` invocation; `-Xtemporary-files-dir` keeps the
object it refers to. Replaying that line with the compiler's own object produces a binary that is
**byte-identical** to the ordinary build. The item's acceptance asked for "within the ruler"; no
measurement is needed for an identity.

So the dependency list is the build's own, not this study's, and no archive is ever chased by
hand. The unbounded part of the old approach is gone.

## 2. The training arm works end to end

Instrumented bitcode carries no profile metadata, so **kotlinc runs its own full pipeline on it**
and emits the object even though its own link step then fails — which is all that was ever wanted
from that invocation. Replaying the captured line with that object, plus
`-u__llvm_profile_runtime` and the rebuilt profile runtime, gives a binary that runs and writes an
`Instrumentation level: IR` profile.

This is the path [B-21](../../docs/backlog/B-21-rq0-the-two-numbers.md) needs on the macro
subject, and it no longer depends on `-Xcompile-from-bitcode` succeeding at link time.

## 3. The **use** arm is not reachable on stock 2.4.20 — and that is a result

A module carrying profile metadata makes kotlinc emit the `CG Profile` module flag **twice**, once
from its LTO pipeline and once from the `clang++` codegen step, and the module is then rejected:

    module flag identifiers must be unique (or of 'require' type)
    !"CG Profile"

The flag is not in the input: `opt -passes=pgo-instr-use` produces a module with **no** `CG
Profile` flag at all. Both copies are kotlinc's.

**The only `-Xllvm-lto-passes` value that avoids it is one that does no LTO.** `default<O3>` and
`default<O2>` both reproduce the failure — they *are* the default pipeline. `verify` builds.

**And once LTO is external, the arm stops being comparable.** Kotlin/Native's own LTO
internalises and dead-strips **3 027 defines down to 411**. `opt -passes=default<O3>` does not do
that, because nothing has told it what may be internalised. Both arms were built that way and both
run correctly, with link lines differing only in the object — but the binary came out
**1 824 320 bytes against the ordinary build's 484 608**, 3.8×.

So an A3 arm built this way would be measured against a pinned build it does not resemble. **This
is a stronger negative than the one this item was opened on.** "The linker failed" invited more
linker work. "A profile-carrying module cannot go through the compiler's own LTO pipeline"
is a property of the toolchain, and it is what a reader needs to know before starting.

## What was not done, and why

**AC 2 — A0-static against A0-dynamic at eight counted rounds — was not run, and is moot.** It
existed to size an assumption: that the training arm's linkage cannot reach the comparison. The
replay removes the premise from both ends. Only the training binary links the profile runtime, so
no measured arm's linkage changes; and A2.3 dropped the macro arms, so there is no comparison left
for the difference to contaminate. Ten minutes of bench time would buy a number nothing consumes.
