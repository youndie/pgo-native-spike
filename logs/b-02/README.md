# B-02 — can the subject host be profiled

Raw output of the runs behind
[B-02's findings](../../docs/backlog/B-02-can-the-subject-host-be-profiled.md). Captured on the
Mac over ssh to `bench-a`; nothing was written on the host that was meant to be kept.

| File | Read it for |
|---|---|
| `2026-09-20-host-survey.log` | `perf_event_paranoid`, `kptr_restrict`, uid, core count, and the Kotlin/Native binaries already on the host |
| `2026-09-20-perf-controls.log` | the two controls — `dd` and `awk`. **The first `dd` report in this file is the misread**: `-g` plus `--sort=dso` showing children, not a missing kernel bucket |
| `2026-09-20-kernel-sampling.log` | `cpu-clock:k` and `cpu-clock:u` recorded separately, `/proc/kallsyms` readable, `perf script` resolving `[kernel.kallsyms]` frames |
| `2026-09-20-clean-control.log` | the control taken properly: one window, no call graph, kernel 51.70 % self, 3 % unresolved |
| `2026-09-20-start-bare.log` | the subject refusing to start without `XYK_DB_PATH`, and the absence of any xyk docker image on the host |
| `2026-09-20-config-keys.log` | empty on purpose — `strings` over the binary finds no `XYK_*` keys, so they were read from the subject's source instead |
| `2026-09-20-profile-xyk.log` | **the run that profiled the wrong pid.** Kept: a 29 kB `perf.data` with one thread is what a correct profile of an idle process looks like too |
| `2026-09-20-profile-xyk-2.log` | the profile that counts — pid taken from `ss`, 6 871 samples, kernel 34.8 %, `kfun:` 21.4 %, unresolved 0 % |
| `2026-09-20-symbol-classes.log` | the leaf census by symbol class, and the `kotlin::` frames that turned out to be demangled C++ rather than a Kotlin prefix |
| `2026-09-20-static-and-prefixes.log` | what those frames actually are, and `ldd` saying the binary is not a dynamic executable |

The `kfun:` share in here is **not** RQ1's answer; the conditions it was taken under are listed in
the item's findings under "What this is not".
