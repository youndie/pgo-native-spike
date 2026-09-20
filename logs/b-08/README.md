# B-08 — RQ0 through Route B

Everything ran on the build box under `~/b08`. The recipe, in full:

```bash
KN=~/.konan/kotlin-native-prebuilt-linux-x86_64-2.4.20
L=~/.konan/dependencies/llvm-21-x86_64-linux-dev-116

$KN/bin/kotlinc-native -opt -Xsave-llvm-ir-directory=$PWD/ir \
    -Xsave-llvm-ir-after=LinkBitcodeDependencies -o base arith.kt
$L/bin/opt -passes="pgo-instr-gen,instrprof" ir/out.LinkBitcodeDependencies.ll -o instr.bc

# the version variable the archive ships says "front-end"; replace it
printf 'long long __llvm_profile_raw_version = (1LL << 56) | 10;\n' > version.c
$L/bin/clang -c -o version.o version.c
mkdir rtx && cd rtx && $L/bin/llvm-ar x $L/lib/clang/21/lib/x86_64-unknown-linux-gnu/libclang_rt.profile.a
rm -f InstrProfilingVersionVar.c.o && cp ../version.o . && $L/bin/llvm-ar rcs ../libprofile-ir.a *.o && cd ..

$KN/bin/kotlinc-native -opt -Xcompile-from-bitcode=$PWD/instr.bc \
    -linker-option -u__llvm_profile_runtime -linker-option $PWD/libprofile-ir.a -o a1
LLVM_PROFILE_FILE=$PWD/i-%p.profraw ./a1.kexe
$L/bin/llvm-profdata merge -output=i.profdata i-*.profraw
$L/bin/opt -passes="pgo-instr-use" -pgo-test-profile-file=$PWD/i.profdata \
    ir/out.LinkBitcodeDependencies.ll -o applied.bc
```

**`-u__llvm_profile_runtime` and the replaced version object are both load-bearing.** Without the
first the binary writes no profile; without the second the profile merges as front-end and
`pgo-instr-use` refuses it.
