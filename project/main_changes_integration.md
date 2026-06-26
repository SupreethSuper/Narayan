# Integration notes — narayan_bdf debug session

## Starting point (your edits)

You had:
- `scheduler.sv` — removed the `beat_cnt`/`mem_idx` debug `$display` (cleanup, kept as removed).
- `scratchpad_memory.sv` — kept the `do_write` fix from the earlier debug pass, and added a
  per-instance `$display`/`$monitor` pair at the bottom for low-level visibility into
  `rw_/cs/data_in/data_out/clk` (kept as-is — left in for now since it's your own debug
  instrumentation; remove later if it gets noisy).
- `tb_narayan_bdf.sv` — rewrote the 90-value burst test down to a small 5-value smoke test
  (write `1,2,3,4,5`, then flip to read mode and wait).

## What was broken in the rewritten testbench

Ran it as-is first (`run_narayan_bdf.do`) to see actual behavior before touching anything:
all four `mem*_out` stayed `0` for the entire run, including during the read-mode hold at
the end.

Two structural bugs caused this:

1. **`repeat(10) @(posedge clk);` warm-up after asserting `cs=1, rw_=0`.**
   `beat_cnt` advances on every `cs && !rw_` clock edge, and each of those edges is a real
   write-commit cycle (via `do_write`). Holding `cs/rw_` active for 10 clock edges before
   ever touching `data_in` meant 10 real cells got written with `data_in`'s leftover value
   (`0`) — clobbering mem1's and mem2's first 10 cells with zeros before `1..5` were ever
   written.

2. **Read mode never advanced `beat_cnt`.** Once `rw_=1`, `beat_cnt` (and therefore
   `rd_addr`/`mem_idx`) is frozen — the testbench just stared at one fixed address forever
   instead of stepping through the cells it had written.

   (Minor: `always` with no `@(posedge clk)` sensitivity also lost its clock-edge
   alignment — it happened to still work here because every path through the block
   consumes time via `#10`/`@(posedge clk)`, but it's not the idiomatic/safe form, so it's
   restored.)

## Fix applied to `tb_narayan_bdf.sv`

Replaced the warm-up + static read-hold with the same write/read-scan pattern proven out
earlier on the 90-value burst test, scaled down to 5 values:

- `cs=1; rw_=0;` then `data_in = 1..5` directly, one per `#10`, **no dead-time gap**
  before the first value. This deliberately sacrifices `beat_cnt=0` (value `1`) to the
  FSM's unavoidable one-cycle `RESET_STATE`→`WRITE_STATE` latency, so `2,3,4,5` land
  correctly at `beat_cnt` 1–4 — all four of those map to `mem_idx=0` (mem1), since
  `mem_idx = (beat_cnt % 20) / 5`.
- After switching to read mode, a 4-step loop pulses `rw_=0` (advance `beat_cnt` by one,
  using `data_in = mem1_out` as a same-value no-op feedback so the forced write doesn't
  clobber the cell being left) then `rw_=1` (read), displaying all four `mem*_out` each
  step.
- Restored `always @(posedge clk)` (was `always` with no sensitivity list).

## Verification

Ran `run_narayan_bdf.do` again after the fix:

```
[65000 ns] write phase done.
[85000 ns] seed read : mem1=0
[115000 ns] scan 1 : mem1=2 mem2=0 mem3=0 mem4=0
[145000 ns] scan 2 : mem1=3 mem2=0 mem3=0 mem4=0
[175000 ns] scan 3 : mem1=4 mem2=0 mem3=0 mem4=0
[205000 ns] scan 4 : mem1=5 mem2=0 mem3=0 mem4=0
```

0 errors, 0 warnings. Value `1` lost (expected/structural), `2,3,4,5` read back correctly
from mem1, and mem2/3/4 correctly read `0` since they were never written by this smaller
test. `output.txt` updated with this run.
