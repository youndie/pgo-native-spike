# B-16 — off-host builds

| File | Read it for |
|---|---|
| `ruler.csv` | the retired `xyk-pagedoff` (arm a) against the new A0 (arm b), eight counted rounds at 120 s settle. Every round `clean`, zero dropped |
| `2026-09-20-comparison.log` | the paired verdict: **+3.71 %, 95 % CI ±3.20 %** — distinguishable, the new binary cheaper |
| `raw/` | the k6 output per round |

The difference is build host **and** source revision together and cannot be decomposed, because
`bench-a` cannot build. It cancels in every future comparison, since all arms now come from one
host and one commit through [`bench/build-arm.sh`](../../bench/build-arm.sh).
