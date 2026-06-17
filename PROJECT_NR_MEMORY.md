# Project NR - Scratchpad Memory Design Memory

## Project Overview

**Project**: Narayan GPU / CNN Accelerator
**Current Focus**: Scratchpad Memory Subsystem (5×5 with 32-bit data)
**Status**: Timing closure in progress
**Platform**: Quartus Prime, Sky130 process

---

## Current Design Architecture

### Module Structure
1. **scratchpad_memory_behave** - Core functional RAM logic
2. **buffer module** - Timing optimization with tree mux
3. **scratchpad_memory** - Top-level integration

### Memory Configuration
- Dimensions: 5 rows × 5 columns (25 locations)
- Data Width: 32 bits
- Address Width: 5 bits (0-24)
- Memory Declaration: 2D array for tree mux `logic [DATA_WIDTH-1:0] memory [ROWS-1:0][COLS-1:0]`
- Total Size: 25 × 32 bits = 800 bits

### FSM States
- **RESET_STATE**: Initialization state
- **READ_STATE**: Read operation (rw_=1)
- **WRITE_STATE**: Write operation (rw_=0)

### Read/Write Protocol
- **Write**: Gated on `next_fsm_state == WRITE_STATE` (1-cycle alignment)
  ```systemverilog
  memory[wr_addr / COLS][wr_addr % COLS] <= data_in;
  ```
- **Read**: Output in READ_STATE with 1-cycle latency
  ```systemverilog
  data_out <= memory[wr_addr / COLS][wr_addr % COLS];
  ```

---

## Critical Design Decisions

### 1. 2D Memory Array (vs 1D flat)
- **Why**: Natural tree mux structure for timing
- **Benefit**: Converts 25:1 cascaded mux → hierarchical 2-level tree mux
- **Indexing**: `[row_index][col_index]` derived from flat address via `wr_addr/COLS` and `wr_addr%COLS`

### 2. Tree Mux Implementation
- **Location**: In separate buffer module
- **Structure**: Parallel bit groups (8 groups of 4 bits each)
- **Parallelization**: Uses generate block at module scope with `genvar`
  ```systemverilog
  generate
    for (genvar i = 0; i < 8; i++) begin : bit_group
      localparam int START = i*4;
      localparam int END = i*4 + 3;
      always_ff @(posedge clk or negedge rst) begin
        // 4-bit parallel register for each group
      end
    end
  endgenerate
  ```

### 3. Write Timing (Gated on next_fsm_state)
- **Why**: Aligns write with address/data on same clock edge
- **Prevents**: Stray writes during state transitions
- **Comment**: "Write when FSM is entering WRITE this cycle"

### 4. FSM Logic (Moved to state transitions)
- **write_done flag removed** from output logic
- **Reason**: FSM now handles write_done guards at state transition level
- **Benefit**: Simplifies output logic, improves timing

---

## Timing Analysis Results

### Latest Slack Report
```
From: fsm_state.READ_STATE
To: data_out[N]~reg0
Slack: -3.174ns (worst case)
Issue: Long combinational path
Extra levels: 1
Recommendation: Reduce logic levels / Duplicate fsm_state signal
```

### Key Issues Identified
1. **High fanout on READ_STATE signal** - Drives all 32 bits of output mux
2. **Inter-path competition** - Nodes being heavily loaded
3. **Critical path**: fsm_state → [tree mux] → output register

### Improvements Made
- Initial: -3.3ns slack (memory cell to output)
- After 2D array + tree mux: -2.909ns slack (+0.4ns improvement)
- After parallelization: TBD (in progress)

---

## Files and Locations

### Core Design Files
- **Design**: `C:\Users\supre\Downloads\Narayan\project\scratchpad_memory.sv`
- **Parameters**: `C:\Users\supre\Downloads\Narayan\project\nar_params.vh`
- **Defines**: `C:\Users\supre\Downloads\Narayan\project\nar_defines.vh`

### Testbenches
- **Simple testbench**: `tb_scratchpad_memory_simple.sv` (8 self-checking tests)
- **Compilation script**: `compile_and_sim_simple.do`

### Synthesis/Timing
- **SDC file**: `narayan.sdc` (timing constraints)
  ```tcl
  create_clock -period 10ns -name clk [get_ports clk]
  ```
- **Target frequency**: 100 MHz (10ns period)

### Git
- **.gitignore**: Added `project/simulation/questa/narayan.svo`

---

## Important Constraints & Lessons

### CRITICAL Constraints
1. **Do NOT modify nar_params.vh or nar_defines.vh** - Global files referenced by many modules
2. **Testbench must be correct** - If TB is faulty, design changes will accommodate the wrong behavior
3. **Cannot add arbitrary pipeline stages** - RAM interface timing is fixed
4. **Cannot use one-hot FSM** - Breaks parameterization flexibility

### FSM State Logic
```systemverilog
READ_STATE: begin
    if (rw_)
        next_fsm_state = READ_STATE;
    else
        next_fsm_state = WRITE_STATE;
end
```
**Note**: RESET_STATE currently does NOT transition to READ_STATE when rw_=1; stays in RESET.

### Data Output During Operations
- **RESET_STATE**: data_out = MEM_ZERO (0x00000000)
- **WRITE_STATE**: data_out = data_out (holds previous value for external readers)
- **READ_STATE**: data_out = memory[...] (with write_done guard removed)

### Address Indexing
```systemverilog
row_index = wr_addr / COLS    // Integer division
col_index = wr_addr % COLS    // Modulo
```
For 5×5: address 0-4 → row 0; address 5-9 → row 1, etc.

---

## Timing Closure Strategy

### Attempted Solutions
1. ✅ **2D Memory Array** - Converted 25:1 cascaded mux to tree structure
2. ✅ **Tree Mux in Buffer Module** - Separated timing concerns
3. ✅ **Parallelized Output Logic** - 8 parallel 4-bit register groups
4. ⏳ **Duplicate READ_STATE Signal** - To reduce fanout (recommended by Quartus)

### Next Steps
1. Verify parallelized READ_STATE synthesizes correctly
2. Check timing after parallelization
3. If still negative, consider:
   - Reduce clock frequency (10ns → 12ns or 15ns)
   - Aggressive Quartus settings (Physical Synthesis, Register Retiming)
   - Cell sizing optimization for critical path

---

## Key SystemVerilog Patterns

### Generate Block at Module Scope (NOT in always_ff)
```systemverilog
// CORRECT: At module level
generate
    for (genvar i = 0; i < N; i++) begin : label
        always_ff @(posedge clk) begin
            // Logic
        end
    end
endgenerate

// WRONG: Inside always_ff
always_ff @(posedge clk) begin
    generate  // ❌ Syntax error
        for ...
    endgenerate
end
```

### 2D Array Access with Tree Mux
```systemverilog
// Declaration
logic [DATA_WIDTH-1:0] memory [ROWS-1:0][COLS-1:0];

// Access (synthesizes as tree mux, not cascaded)
data <= memory[row][col];
```

---

## Testing Notes

### Self-Checking Testbench (tb_scratchpad_memory_simple.sv)
- 8 focused tests
- Assertions on data correctness
- Auto pass/fail reporting
- Coverage: RESET/READ/WRITE transitions, write_done behavior, latency

### Run Command
```bash
vsim -c -do compile_and_sim_simple.do
```

### Expected Test Results
- T1: RESET→READ outputs 0x00000000
- T2: WRITE→READ outputs valid data
- T3: READ→READ outputs consistent data
- T4: Multi-address coverage
- T5: Last-write-wins verification
- T6: Chip select behavior
- T7: 2D addressing (tree mux)
- T8: Reset state restoration

---

## Known Issues & Workarounds

### Issue 1: Negative Slack on READ_STATE Path
- **Cause**: High fanout of fsm_state signal on 32-bit mux
- **Workaround**: Parallelize output into 8 groups with separate control
- **Status**: Implementation in progress

### Issue 2: Missing Timing Constraints
- **Symptom**: "narayan.sdc not found" warning
- **Solution**: Create SDC with clock constraint
- **File**: `narayan.sdc` (minimal: just clock period)

### Issue 3: 2D Array Indexing Overhead
- **Potential**: Division/modulo operations (wr_addr/COLS, wr_addr%COLS)
- **Actually**: Compiler optimizes to bit shifts/masks for constant COLS
- **Status**: No additional delay observed

---

## Contact & Collaboration

**User**: Supreeth (sathrey5@asu.edu)
**Project Location**: `C:\Users\supre\Downloads\Narayan\project`
**Tools**: Quartus Prime (Windows), ModelSim, Yosys (optional)
**Process Target**: Sky130 (via OpenLane in future)

---

## Next Session Checklist

- [ ] Run timing analysis with parallelized READ_STATE
- [ ] Verify slack improvement vs -3.174ns baseline
- [ ] If slack still negative: adjust clock period or enable physical synthesis
- [ ] Prepare for synthesis with Yosys/OpenLane
- [ ] Physical design review in KLayout
- [ ] Integration into larger Narayan accelerator

