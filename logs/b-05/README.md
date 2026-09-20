# B-05 — the unknowns of the release pipeline

No raw logs: every answer came from reading the clone at `~/kotlin-fork` on the build box
(`890ac1d94`, the pinned tag) and from listing the toolchain that was already installed, with two
exceptions that were run and are reproducible in one command each:

- `-Xsave-llvm-ir-after=LinkBitcodeDependencies` on the arithmetic control, twice, to compare the
  IR across builds — 12 differing lines of 170 364, ten of them one UUID and two of them the
  output path;
- `opt -print-all-options -passes=pgo-icall-prom` for the promotion thresholds.

The findings are in the item.
