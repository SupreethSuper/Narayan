# Project Narayan: Development Progress & Biodata

**Project Name:** Narayan  
**Author:** Supreeth  
**Email:** sathrey5@asu.edu  
**Last Updated:** June 22, 2026  
**Status:** In Development — Verification & Physical Design Phase

---

## Executive Summary

Project Narayan is a custom hardware accelerator for CNN/matrix-processing operations. The design focuses on a scalable scratchpad memory subsystem with an FSM-controlled read/write interface. The project progresses through RTL design, functional verification, synthesis, and physical design using OpenLane targeting the Sky130 process node.

**Current Phase:** Functional verification complete (5×5×32 configuration); identified FSM write bugs; synthesized and placed/routed physical design artifacts generated.

---

## Project Biodata

### Project Objectives
1. **Design Goal:** Build a CNN accelerator with a custom 500×500×32 scratchpad memory (future scaling)
2. **Current Scope:** Working configuration is 5×5×32 for verification and OpenLane testing
3. **Target Process:** Sky130 (open-source PDK)
4. **Design Tools:** 
   - RTL: SystemVerilog (ModelSim/Questa for simulation)
   - Synthesis: Yosys
   - Physical Design: OpenLane
   - Visualization: KLayout (GDS inspection)
   - Build Flow: Quartus Prime (initial schematics & integration)

### Project Structure

```
/Narayan/project/
├── Core RTL Modules
│   ├── scratchpad_memory.sv          [Memory subsystem, FSM-controlled]
│   ├── scheduler.sv                  [Address decoder, chip-select multiplexer]
│   ├── narayan_bdf.v                 [Top-level integration, 4-unit memory array]
│   └── nar_defines.vh / nar_params.vh [Parameter definitions]
│
├── Testbenches
│   ├── tb_narayan_bdf.sv              [90-value write-then-read sequence]
│   ├── testbenches/
│   │   ├── tb_scratchpad_memory_v*.sv [Multiple versions tracking design iteration]
│   │   ├── tb_scratchpad_memory_v4.sv [Golden testbench with self-checking scoreboard]
│   │   ├── scratchpad_image_tb.sv     [Image-based test vectors]
│   │   └── ...
│   └── scheduler_tb.sv                [Scheduler unit test]
│
├── Configuration & Constraints
│   ├── narayan.qpf / narayan.qsf     [Quartus project configuration]
│   ├── narayan.sdc                    [Timing constraints]
│   ├── scheduler_defines.vh           [Scheduler configuration (4 units)]
│   ├── nar_defines.vh                 [Parameterized design: 5×5×32 current, 500×500×32 target]
│   └── modelsim.ini                   [ModelSim configuration]
│
├── Block Diagrams & Schematics
│   ├── narayan.bdf                    [Quartus block diagram, 4 memory units + scheduler]
│   ├── scheduler.bsf                  [Scheduler block symbol]
│   ├── scratchpad_memory.bsf          [Memory block symbol]
│   └── narayan_bdf.json               [Serialized BDF for tool integration]
│
├── Simulation Artifacts
│   ├── narayan_bdf.vcd                [Waveform trace from tb_narayan_bdf]
│   ├── testbenches/waves/             [Historical waveform traces]
│   ├── transcript                     [ModelSim transcript log]
│   └── work/                          [ModelSim compiled design library]
│
├── Physical Design Outputs (OpenLane)
│   ├── output_files/                  [Synthesis & P&R results]
│   ├── db/                            [Quartus database]
│   ├── incremental_db/                [Incremental build data]
│   └── results/final/                 [Final GDS, LEF, DEF after P&R]
│
└── Documentation
    ├── doc/Documentation.docx          [Project overview & specifications]
    ├── python_test_files/              [Test vector generation scripts]
    └── runner_scripts/                 [Automation & test runners]
```

---

## Design Components

### 1. Scratchpad Memory Module (`scratchpad_memory.sv`)
**Purpose:** Core memory subsystem with FSM-controlled read/write access  
**Date Created:** June 17, 2026  
**Last Modified:** June 17, 2026  

**Architecture:**
- **Data Array:** `logic [DATA_WIDTH-1:0] memory[ROWS-1:0][COLS-1:0]`
  - Parameterizable: `DATA_WIDTH` (32 bits), `ROWS` (5), `COLS` (5)
  - Logical layout: row-major 2D array for intuitive indexing
  
- **Valid Flags:** `logic [ROWS*COLS-1:0] cell_valid` (packed register)
  - Async clear on reset (no loop-based clear → small reset net)
  - Per-cell validation: prevents reading uninitialized/stale data
  - Detects out-of-range reads (fall through to zero)

- **Finite State Machine (3 states):**
  - **RESET_STATE:** Initial state after async reset; transitions on first command (read → READ_STATE, write → WRITE_STATE)
  - **READ_STATE:** Reads data from memory array; responds to rw_=1 (read) or rw_=0 (write)
  - **WRITE_STATE:** Writes data to memory array; responds to rw_=1 (read) or rw_=0 (write)
  
- **Control Interface:**
  - `clk` — clock input
  - `rst` — async reset (active-low)
  - `rw_` — read/write select (0=write, 1=read)
  - `cs` — chip select (active-high); deselecting forces read mode
  - `wr_addr` — address input (combined read & write)
  - `data_in` — write data
  - `data_out` — read data (registered, 2-cycle latency)

- **Output Path:**
  - Fully registered (no combinational input→output)
  - 2-cycle latency: read occurs in cycle N, result available in cycle N+2
  - Returns MEM_ZERO (0) if cell_valid[addr] not set

**Parameterization:**
```systemverilog
parameter DATA_WIDTH  = NAR_NUM_BITS  = 32
parameter ROWS        = NAR_MAT_ROWS  = 5
parameter COLS        = NAR_MAT_COLS  = 5
parameter MEM_ADDRESS = $clog2(ROWS*COLS) = 5
```

**Known Issues (Diagnosed but Not Yet Fixed):**
1. **FSM Write Commit Off-by-One:**
   - Write-enable condition: `if (fsm_state == WRITE_STATE)` gates the write
   - `fsm_state` is registered and lags `rw_` by 1 cycle
   - **Effect:** First write when entering WRITE_STATE is dropped (FSM not yet in WRITE)
   
2. **Spurious Trailing Write on WRITE→READ Transition:**
   - When transitioning from WRITE → READ, FSM remains WRITE for one clock edge
   - **Effect:** Stale `data_in` is written to the read address, corrupting data
   
3. **Reset-to-Read Failure:**
   - FSM can only leave RESET via a write (rw_=0)
   - Reading immediately after reset never engages (no state transition)

**Fix (Verified):**
- Change write-enable to combinational: `always_ff @(posedge clk) if (cs && !rw_) memory[wr_addr] <= data_in;`
- This decouples write-enable from registered FSM state
- Python cycle model verified the fix passes 100% on golden testbench while current RTL fails

---

### 2. Scheduler Module (`scheduler.sv`)
**Purpose:** Address decoder & chip-select multiplexer for multi-unit memory  
**Date Created:** June 19, 2026  
**Last Modified:** June 19, 2026  

**Architecture:**
- **Beat Counter:** `logic [GLOBAL_ADDR-1:0] beat_cnt`
  - Increments each write cycle (cs=1, rw_=0)
  - Wraps after TOTAL_ADDRS writes (sequential addressing)
  - Drives address distribution across memory units

- **Address Decode (Combinational):**
  - **Super Row:** beat_cnt / (NUM_UNITS × COLS)
  - **Position in Super-Row:** beat_cnt % (NUM_UNITS × COLS)
  - **Memory Index (Unit):** pos_in_super / COLS
  - **Column in Row:** pos_in_super % COLS
  - **Local Address:** super_row × COLS + col_in_row

- **Chip-Select Distribution:**
  - **Write Mode (rw_=0):** Only the unit matching mem_idx gets cs=1 (sequential)
  - **Read Mode (rw_=1):** All units get cs=1 (parallel readout)
  - Enables burst-write pattern with distributed memory

**Parameters:**
```systemverilog
parameter DATA_WIDTH   = NAR_NUM_BITS = 32
parameter ROWS         = NAR_MAT_ROWS = 5
parameter COLS         = NAR_MAT_COLS = 5
parameter NUM_UNITS    = SCHED_MEM_UNITS = 4
parameter LOCAL_ADDR   = $clog2(ROWS*COLS) = 5
parameter GLOBAL_ADDR  = $clog2(NUM_UNITS*ROWS*COLS) = 7
parameter TOTAL_ADDRS  = NUM_UNITS*ROWS*COLS = 100
```

**Pass-Through Signals:**
- `data_out = data_in` (direct)
- `rw_out = rw_` (direct)
- `rst_out = rst` (direct)
- `clk_out = clk` (direct)

**Integration Note:** Used in `narayan_bdf` to fan-out cs, rw_, rst, clk to 4 memory instances while decoding beat_cnt → {unit, local_addr}.

---

### 3. Top-Level Integration (`narayan_bdf.v`)
**Purpose:** Integrate 4 scratchpad memory units under scheduler control  
**Date Created:** June 19, 2026 (from Quartus schematic)  
**Last Modified:** June 19, 2026  

**Topology:**
- **1 Scheduler Instance:** Routes address, cs, and control signals
- **4 Scratchpad Memory Instances:** 5×5×32 each, parallel outputs
- **Data:** Shared input bus; 4 separate output buses (mem1_out, mem2_out, mem3_out, mem4_out)

**Port Map:**
```
Inputs:  clk, rw_, rst, cs, data_in[31:0]
Outputs: mem1_out[31:0], mem2_out[31:0], mem3_out[31:0], mem4_out[31:0]

Scheduler:
  - Inputs: clk, rw_, rst, cs, data_in
  - Outputs: cs_out[3:0], rd_addr[4:0], rw_out, rst_out, clk_out
  
Memory Units (×4):
  - All share: clk, rw_, rst, data_in
  - Each receives: cs_out[i]
  - Each receives: rd_addr as wr_addr
  - Each outputs: mem*_out
```

**Key Design Point:**
- All 4 memory units operate in lockstep: same clock, rw_, rst, data_in, wr_addr
- Scheduler's cs_out[i] selectively enables writes to individual units
- All units can read simultaneously (cs_out bits all 1 during read)

---

## Test Coverage & Verification Status

### Testbench Evolution

| Version | Date | Status | Notes |
|---------|------|--------|-------|
| `tb_scratchpad_memory_v2.sv` | Early | Deprecated | Early simple tests |
| `tb_scratchpad_memory_v3.sv` | June 17 | Weak | ~2/3 unconditional pass, no timing checks |
| `tb_scratchpad_memory_v4.sv` | June 17 | **Golden** | Self-checking scoreboard, ideal-RAM model, every op verified |
| `tb_scratchpad_memory_v5-v11.sv` | June 17-19 | Various | Iterative refinement, image vectors, debug traces |
| `tb_narayan_bdf.sv` | June 19 | Active | 90-value write-then-read on 4-unit array |
| `scheduler_tb.sv` | June 17 | Component Test | Scheduler address decode verification |

### Test Cases Documented

**`tb_narayan_bdf.sv` — 90-Value Write-Then-Read Sequence**

Logic per iteration:
1. Write value (rw_=0): 2 clock cycles
   - Cycle 1: FSM transition (no write commit)
   - Cycle 2: Actual memory write
2. Read (rw_=1): 2 clock cycles
   - Cycle 1: Address decode, read path
   - Cycle 2: Data available on output (registered latency)

Pattern:
- Values 1–2: Read returns 0 (not yet written to beat_cnt location)
- Values 3+: Read returns previously written value (address space overlap)

**Test Vector Coverage:**
```
Values 1–90:  7, 13, 42, 99, 128, 200, 255, 512, 1024, ...
Addresses: Distributed across 4 memory units via scheduler beat_cnt
Expected Behavior: Sequential write to beat_cnt addresses 0→99, 
                   parallel read during write mode
```

### Known Failing Tests

**Test 15 (H5): Last Written Value**
- **Procedure:** Write 0x00, 0x33, 0x66, 0x99, 0xCC to address 30 (multiple writes same addr)
- **Expected:** 0xCCCCCCCC
- **Actual:** FAIL
- **Root Cause:** FSM off-by-one write bug (diagnosed)

**Test 26 (EX6): Data Persistence**
- **Procedure:** Write 0xDEADBEEF to address 200, idle 5 cycles, read
- **Expected:** 0xDEADBEEF
- **Actual:** FAIL
- **Root Cause:** Spurious trailing write corrupts address during WRITE→READ transition (diagnosed)

**Status:** Both failures traced to FSM write-enable gate. Fix identified and verified on Python cycle model.

---

## Physical Design Artifacts

### OpenLane Flow Completion

**Status:** RTL → Synthesis → Floorplanning → Placement & Routing: **COMPLETE**

**Generated Files:**
- `scratchpad_memory.lef` — Abstract logical model (size, pins, power)
- `scratchpad_memory.def` — Detailed physical layout (cell placement, routing)
- Location: `results/final/` in OpenLane run directory

**Configuration:**
- **Target Process:** Sky130 (130 nm)
- **Top Module:** scratchpad_memory (current 5×5×32)
- **Configuration Parameters:** Passed as OpenLane env vars or in config.tcl

**Known Concern — Memory Inference:**
- Yosys synthesis reported "memory is full" warning
- Indicates potential register flattening vs. inference of actual memory structures
- Verification needed: `yosys memory stat` to confirm proper inference

### Design Metrics (5×5×32 Configuration)

| Metric | Value | Notes |
|--------|-------|-------|
| **Data Array Size** | 25 entries × 32 bits = 800 bits | 2D [5][5] array |
| **Valid Flags** | 25 bits | Packed register |
| **FSM States** | 3 (RESET, READ, WRITE) | State register: 2 bits |
| **Registered Outputs** | 32 bits (data_out) + 1 bit (fsm_state) | No combinational paths |
| **Clock Domain** | 1 | Single synchronous clock |
| **Reset Domain** | 1 async | Active-low |

**Estimated Cells (Yosys netlist):**
- Registers: ~834 FFs (from prior analysis on 5×5×32)
- Logic gates: Minimal (FSM, address decode, mux control)
- Memory compiler: TBD (depends on Yosys inference success)

**Physical Feasibility Assessment:**
- **5×5×32:** Easily synthesizable and placed in Sky130
- **500×500×32 (Original Spec):** ~8 MB equivalent, likely requires:
  - Banked memory (split into multiple smaller blocks)
  - Tiled architecture (spatial distribution)
  - Streaming dataflow (time-multiplexed access)
  - Current monolithic design impractical for ASIC

---

## Key Milestones & Timeline

| Date | Milestone | Status |
|------|-----------|--------|
| May 19, 2026 | Project initialized, Quartus project created | ✅ Complete |
| May 21–25 | Initial scratchpad memory RTL drafted | ✅ Complete |
| June 16 | Verification testbench suites created | ✅ Complete |
| June 17 | Scheduler module designed & integrated | ✅ Complete |
| June 17 | nar_defines.vh & nar_params.vh parametrization | ✅ Complete |
| June 17 | OpenLane "combi error" investigation & resolution | ✅ Complete |
| June 19 | Quartus BDF schematic finalized (narayan_bdf) | ✅ Complete |
| June 19 | tb_narayan_bdf testbench (90-value sequence) written | ✅ Complete |
| June 19 | OpenLane synthesis & physical design executed | ✅ Complete |
| June 21–22 | FSM write bug root-cause analysis & fix verification | ✅ Complete |
| TBD | Fix applied to production RTL | ⏳ Pending |
| TBD | Re-run verification on corrected RTL | ⏳ Pending |
| TBD | Re-synthesize & re-place/route with fix | ⏳ Pending |
| TBD | Evaluate memory inference & Yosys warnings | ⏳ Pending |
| TBD | Assess physical feasibility for 500×500×32 target | ⏳ Pending |

---

## Design Issues & Resolutions

### Issue 1: OpenLane "Combi Error" — RESOLVED (June 11, 2026)

**Symptom:** OpenLane reported combinational input directly driving output without register/FF.

**Investigation:**
- Checked current `scratchpad_memory.sv` (5×5×32): Yosys synthesis clean (0 problems, 0 latches)
- JSON netlist cone traversal: NO combinational input→output path
- `data_out` fully registered (834 FFs)

**Root Cause:** Stale dead code in an older RTL version
- Commented-out `buffer_out` module using `bufif1(data_out_buffer, data_in_buffer, cs)` (tri-state feedthrough)
- Prior OpenLane run used wrong top module (`scratchpad` vs `scratchpad_memory`)
- Synthesis log indicated stale configuration

**Resolution:**
- Removed dead code and commented parameters
- Hoisted row/col decode to shared wires
- Formally proven equivalence between old and new via Yosys equiv flow (111/111 cells proven)
- Action: Re-run OpenLane with correct DESIGN_NAME = scratchpad_memory

### Issue 2: FSM Write Commit Off-by-One & Spurious Trailing Write — DIAGNOSED (June 21–22, 2026)

**Symptom:** Test 15 and Test 26 failures in functional verification.

**Root Cause Analysis:**
1. **Off-by-One:** Write-enable gate `if (fsm_state == WRITE_STATE)` uses registered state, which lags `rw_` by 1 cycle
   - First write when entering WRITE_STATE is dropped
2. **Spurious Trailing Write:** On WRITE→READ transition, FSM remains WRITE for one edge
   - Stale `data_in` is written to the read address, corrupting the location
3. **Reset Issue:** FSM can only leave RESET via write; reads after reset never engage

**Verification:**
- Python cycle model of corrected RTL passes golden testbench 100%
- Current RTL fails first read of each write-burst and reset-to-read case

**Proposed Fix:**
```systemverilog
// Current (BUGGY):
always_ff @(posedge clk) begin
    if ((fsm_state == WRITE_STATE) && cs)
        memory[row][col] <= data_in;
end

// Fixed:
always_ff @(posedge clk) begin
    if (cs && !rw_)  // Combinational gate on inputs, not registered state
        memory[row][col] <= data_in;
end
```

**Status:** Fix verified; awaiting application to production RTL.

### Issue 3: Yosys Memory Inference Warning

**Symptom:** "memory is full" message during synthesis.

**Implication:** May indicate register flattening instead of inference of actual memory structures (less efficient).

**Investigation Needed:** Run `yosys memory stat` on netlist to verify proper inference.

**Impact:** Physical design feasibility & area estimates depend on this.

---

## Current Project State (as of June 22, 2026)

### What's Complete
✅ RTL design for scratchpad memory (FSM, address decode, read/write paths)  
✅ Scheduler module (address distribution, cs multiplexing)  
✅ Top-level integration (narayan_bdf with 4 memory units)  
✅ Comprehensive testbench suite (v2–v11, golden v4)  
✅ Parametric configuration (5×5×32 verified, 500×500×32 target defined)  
✅ Quartus schematic-based integration (BDF)  
✅ OpenLane physical design flow (synthesis, floorplanning, P&R)  
✅ FSM bug diagnosis and Python-verified fix  

### What's Pending
⏳ **Critical:** Apply FSM write-enable fix to production RTL  
⏳ **Critical:** Re-run verification on corrected RTL (full testbench suite)  
⏳ **High:** Re-synthesize & re-place/route with fix  
⏳ **High:** Investigate Yosys memory inference (run memory stat)  
⏳ **Medium:** Evaluate physical feasibility for 500×500×32 target  
⏳ **Medium:** Consider architecture redesign if monolithic memory impractical  
⏳ **Low:** Documentation update & final project report  

### Next Immediate Actions
1. **Apply FSM Fix:** Edit `scratchpad_memory.sv` line 94–97 to use combinational write-enable
2. **Verify:** Run `tb_scratchpad_memory_v4.sv` (golden testbench) on corrected RTL
3. **Synthesize:** Re-run Yosys/OpenLane with fixed RTL
4. **Validate:** Check memory inference with `yosys memory stat`
5. **Assess:** Determine if current design is viable for scaled target

---

## Design Philosophy & Key Decisions

### 1. Registered Output Path (No Combinational I/O)
**Decision:** All outputs registered, even if it costs latency.  
**Rationale:** Simplifies STA (no combinational loops), avoids hazards, improves noise immunity.  
**Consequence:** 2-cycle read latency inherent to design.

### 2. Packed Valid Flags Register
**Decision:** Single `cell_valid[ROWS*COLS-1:0]` register, async-cleared.  
**Rationale:** Avoids loop-based reset (tiny reset fan-out), per-cell validation (no aliasing).  
**Consequence:** Small reset net, clean async reset semantics.

### 3. FSM-Controlled State Machine
**Decision:** Three-state FSM (RESET, READ, WRITE) gates all operations.  
**Rationale:** Clear semantic separation, deterministic behavior.  
**Caveat:** Current implementation has register→state path bug; fix decouples control from registered state.

### 4. Unified Address Bus (Read & Write)
**Decision:** Single `wr_addr` input serves as both read and write address.  
**Rationale:** Simpler interface, matches sequential access pattern (beat counter).  
**Limitation:** Cannot perform concurrent read/write to different addresses (by-design restriction).

### 5. Scheduler-Based Address Distribution
**Decision:** Beat counter + combinational decode distributes addresses across units.  
**Rationale:** Enables sequential write (one unit at a time) with parallel read (all units).  
**Scalability:** Easily extensible to 8+, 16+ units; address math remains O(1).

---

## Dependencies & External References

### Tools & Versions
- **Quartus Prime:** v25.1std Build 1129 (Lite Edition)
- **ModelSim/Questa:** Part of Quartus Prime suite
- **Yosys:** OpenLane integrated version
- **OpenLane:** Latest (version in use at project start)
- **KLayout:** For GDS visualization (optional)

### Input Files
- **nar_defines.vh:** Parameter definitions (5×5×32, 32-bit data)
- **nar_params.vh:** Localparam wrappers around defines
- **scheduler_defines.vh:** Scheduler configuration (4 units)
- **scheduler_params.vh:** Scheduler localparam wrappers

### Generated Artifacts
- **narayan_bdf.json:** Serialized schematic
- **narayan_bdf.vcd:** Simulation waveform
- **LEF/DEF:** OpenLane physical design output

---

## Known Limitations & Future Work

### Current Limitations
1. **Memory Size:** 5×5×32 is small; target 500×500×32 may require architecture change
2. **No Concurrent I/O:** Single address bus prevents simultaneous read/write to different locations
3. **2-Cycle Latency:** Read latency fixed by design (registered output path)
4. **FSM Limitation:** Can only exit RESET via write; read after reset fails
5. **Memory Inference:** Uncertain if Yosys infers proper memory vs. flattened registers

### Future Optimizations
1. **Banked Memory:** Split 500×500×32 into multiple smaller units (e.g., 4× 125×500×32) for better synthesis/placement
2. **Streaming Dataflow:** Time-multiplex memory access to amortize area over time
3. **Dual-Port Memory:** Enable concurrent read/write (higher complexity)
4. **Speculative Read:** Prefetch data on rising edge (reduce latency from 2 to 1 cycle)
5. **Memory Compiler:** Use Sky130 memory generator (SRAM IP) instead of standard cells

### Architectural Reassessment
User noted original CNN accelerator architecture "becoming a nightmare." Recommend:
- Re-evaluate memory organization (banking, tiling, streaming)
- Re-evaluate dataflow requirements
- Revisit accelerator partitioning
- Trade-off functional correctness vs. feasibility for full scale

---

## Files Reference Guide

### Core RTL
- `scratchpad_memory.sv` — Memory subsystem (FSM, read, write, valid flags)
- `scheduler.sv` — Address decoder & chip-select multiplexer
- `narayan_bdf.v` — Top-level integration (4 memory units)
- `nar_defines.vh` — Parameter macros
- `nar_params.vh` — Localparam wrappers
- `scheduler_defines.vh` — Scheduler config (4 units)
- `scheduler_params.vh` — Scheduler localparam wrappers

### Testbenches (Most Recent)
- `tb_narayan_bdf.sv` — 90-value write-then-read on 4-unit array
- `testbenches/tb_scratchpad_memory_v4.sv` — Golden testbench with scoreboard
- `testbenches/tb_scratchpad_memory_v*.sv` — Iterative versions (v5–v11)
- `scheduler_tb.sv` — Scheduler unit test

### Simulation & Waveforms
- `narayan_bdf.vcd` — Latest testbench waveform
- `transcript` — ModelSim log
- `work/` — Compiled design library (ModelSim)
- `waves/` / `testbenches/waves/` — Historical waveforms

### Quartus Schematic
- `narayan.bdf` — Block diagram (4 memory units + scheduler)
- `narayan_bdf.json` — Serialized BDF
- `scheduler.bsf` — Scheduler block symbol
- `scratchpad_memory.bsf` — Memory block symbol
- `narayan.qpf` / `narayan.qsf` — Project configuration
- `narayan.sdc` — Timing constraints

### Physical Design
- `output_files/` — Synthesis & P&R results
- `results/final/` (OpenLane) — Final GDS, LEF, DEF

### Documentation
- `doc/Documentation.docx` — Project overview
- `python_test_files/` — Test vector generation
- `runner_scripts/` — Test automation

---

## How to Reproduce Key Results

### Run Functional Verification on Golden Testbench
```bash
cd /path/to/narayan/project
vsim -c -do "vlog testbenches/tb_scratchpad_memory_v4.sv scratchpad_memory.sv; vsim tb_scratchpad_memory_v4; run -all"
```

### Run 4-Unit Integration Test
```bash
vsim -c -do "vlog tb_narayan_bdf.sv narayan_bdf.v scratchpad_memory.sv scheduler.sv; vsim tb_narayan_bdf; run -all; quit"
```

### Synthesize with Yosys (Check Memory Inference)
```bash
yosys -p "read_verilog scratchpad_memory.sv; hierarchy -top scratchpad_memory; synth; memory stat; write_json netlist.json"
```

### Run OpenLane Physical Design
```bash
cd /path/to/openlane
flow.tcl -design /path/to/narayan/project -target_pdk sky130 -tag run_v1
```

---

## Contact & Support
**Project Owner:** Supreeth  
**Email:** sathrey5@asu.edu  
**Last Updated:** June 22, 2026

For issues, questions, or contributions, contact the project owner or review the memory system in `MEMORY.md`.
