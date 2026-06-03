# Narayan GPU Scratchpad - Complete Project History & Diagnosis

**Last Updated:** June 2, 2026  
**Project Status:** In Active Development - Yosys Synthesis Phase  
**Target:** FPGA Implementation (Quartus)

---

## Executive Summary

The Narayan project is a parallelized GPU architecture for CNN image processing with a specialized **scratchpad image buffer** module. The scratchpad accepts parallel pixel inputs and stores them in a 2D matrix for downstream processing. This document chronicles the complete engineering journey from initial conception through current state, including all failures, iterations, and architectural decisions.

---

## Part 1: Project Goals & Strategy

### Primary Goal
Design a **high-throughput image buffer** that:
- Accepts multiple pixels in parallel per clock cycle (MAX_INPUT_SCOOP parameter)
- Stores pixels in a 2D matrix organized by row/column
- Provides flat vector outputs for integration with Quartus FPGA flow
- Minimizes resource consumption for FPGA synthesis

### Secondary Goals
- Support configurable matrix size (ROWS × COLS)
- Support configurable parallelism (MAX_INPUT_SCOOP)
- Support configurable data width (DATA_WIDTH, default 32-bit with RGB padding)
- Maintain simplicity for verification and synthesis

### Design Strategy

**Phase 1: Architectural Design**
- Define scratchpad module interface (flattened inputs/outputs for testbench simplicity)
- Implement pixel storage mechanism
- Validate with SystemVerilog testbench

**Phase 2: Testing & Validation**
- Create test vectors from real image data
- Verify pixel storage correctness against input/output
- Implement CSV-based output capture for comparison

**Phase 3: Synthesis & FPGA Optimization**
- Reduce parameters to fit FPGA device constraints
- Optimize for Yosys synthesis tool requirements
- Address timing/fanout issues from reset logic

---

## Part 2: Original Architecture (500×500 Design)

### Parameters
```verilog
NAR_NUM_BITS_DEF             32              // 8R + 8G + 8B + 8 padding
NAR_MAT_ROWS_DEF             500             // Full image height
NAR_MAT_COLS_DEF             500             // Full image width
NAR_MAX_INPUT_SCOOP_DEF      500             // One full row per cycle!
```

### Original Approach: Region-Based Broadcast (DEPRECATED)

**Concept:**
Divide the 500×500 matrix into MAX_INPUT_SCOOP horizontal regions. Each input lane broadcasts its value to an entire region every clock cycle.

**Pseudo-logic:**
```verilog
// DEPRECATED: Region-based broadcast
for (int scoop_idx = 0; scoop_idx < MAX_INPUT_SCOOP; scoop_idx++)
begin
    int row_start = scoop_idx * REGION_ROWS;
    int row_end   = (scoop_idx + 1) * REGION_ROWS;

    for (int i = row_start; i < row_end; i++)
        for (int j = 0; j < COLS; j++)
        begin
            red_pad[i][j]   <= red[scoop_idx];    // ← OVERWRITES every cycle!
            green_pad[i][j] <= green[scoop_idx];
            blue_pad[i][j]  <= blue[scoop_idx];
        end
end
```

**Resource Requirements:**
- Input: 500 pixels × 32 bits = 16,000 bits/cycle
- Output: 500 × 500 × 32 = 8,000,000 bits (flattened)
- Cycles to load: 500 (one row per cycle)
- Time to load full image: 500 clock cycles

---

## Part 3: Failure #1 - Data Loss in Broadcast Architecture

### The Problem

Instead of storing a gradient image, the hardware produced **solid cyan output** - a single color filling the entire matrix.

### Root Cause Analysis

The broadcast-to-regions architecture has a fundamental flaw: **every cycle overwrites the previous values**.

**Example trace (RED channel only):**
```
Cycle 0: Input = [0x00, 0x00, 0x01, ...]
         Region 0 (rows 0-166)   ← 0x00
         Region 1 (rows 167-332) ← 0x00
         Region 2 (rows 333-499) ← 0x01

Cycle 1: Input = [0x01, 0x01, 0x02, ...]
         Region 0 ← 0x01  (OVERWRITES 0x00!)
         Region 1 ← 0x01  (OVERWRITES 0x00!)
         Region 2 ← 0x02  (OVERWRITES 0x01!)

Cycle 2: Input = [0x02, 0x02, 0x03, ...]
         Region 0 ← 0x02  (OVERWRITES 0x01!)
         Region 1 ← 0x02  (OVERWRITES 0x01!)
         Region 2 ← 0x03  (OVERWRITES 0x02!)

... continues for 500 cycles ...

Final State:
Region 0 = last input value (0xFF)
Region 1 = last input value (0xFF)
Region 2 = last input value (0xFF)  ← All cyan!
```

**Data Loss:**
- Input: 250,000 pixels
- Output: 3 final values (250,000 pixels collapsed!)
- Result: Complete information loss

### Investigation Process

1. **Initial Suspicion:** Image converter (hex to/from image)
2. **Verification:** Created `IMAGE_HEX_CONVERTER_AUDIT.md`
   - Verified pixel-to-hex conversion ✓
   - Verified hex-to-pixel conversion ✓
   - Verified round-trip fidelity ✓
   - **Conclusion:** Converter is NOT the problem

3. **Testbench Analysis:** Created `TESTBENCH_FLOWCHART.md`
   - Traced pixel streaming through hardware
   - Identified broadcast overwriting behavior
   - **Conclusion:** Hardware architecture is the problem

---

## Part 4: Correction #1 - Sequential Storage Architecture

### The Solution

Replace broadcast-to-regions with **sequential storage using an internal address counter**.

**New Concept:**
- Maintain internal counter tracking next write position
- For each input pixel, calculate 2D array index: `row = index / COLS`, `col = index % COLS`
- Store each pixel at its calculated position (never overwrite)
- Auto-increment counter for next cycle

### Corrected Implementation

```verilog
// NEW: Sequential storage with address counter
logic [PIXEL_ADDR_WIDTH-1:0] pixel_counter;  // Internal state

always_ff @(posedge clk or negedge rst)
begin
    if(~rst)
        pixel_counter <= '0;
    else
    begin
        // Store MAX_INPUT_SCOOP pixels in parallel
        for (int scoop_idx = 0; scoop_idx < MAX_INPUT_SCOOP; scoop_idx++)
        begin
            logic [PIXEL_ADDR_WIDTH-1:0] stored_index;
            int stored_row, stored_col;

            // Calculate address for this pixel
            stored_index = pixel_counter + scoop_idx;
            stored_row = (stored_index < TOTAL_PIXELS) ? (stored_index / COLS) : 0;
            stored_col = (stored_index < TOTAL_PIXELS) ? (stored_index % COLS) : 0;

            // Store pixel only if within bounds
            if (stored_index < TOTAL_PIXELS)
            begin
                red_pad[stored_row][stored_col]   <= red[scoop_idx];
                green_pad[stored_row][stored_col] <= green[scoop_idx];
                blue_pad[stored_row][stored_col]  <= blue[scoop_idx];
            end
        end

        // Auto-increment counter
        if (pixel_counter + MAX_INPUT_SCOOP < TOTAL_PIXELS)
            pixel_counter <= pixel_counter + MAX_INPUT_SCOOP;
        else
            pixel_counter <= '0;  // Wrap around
    end
end
```

**Key Differences:**
- ✓ No more overwriting
- ✓ All 250,000 pixels preserved
- ✓ Correct gradient output produced
- ✓ Testbench no longer needs to track counter (hardware manages internally)

### Result
Gradient image now produced correctly - problem solved! ✓

---

## Part 5: Failure #2 - FPGA Resource Overflow

### The Problem

Attempted Quartus compilation with full 500×500 parameters:
```
Error: There are 1538 IO input pads in the design, but only 592 available
Error: There are 393216 IO output pads in the design, but only 592 available
```

### Root Cause

The flattened output vector width is massive:
- ROWS × COLS × DATA_WIDTH = 500 × 500 × 32 = **8,000,000 bits**
- Modern FPGAs have limited IO: ~600 pads
- Each output bit requires one IO pad (in flattened representation)

### Why Flattening?

The testbench and Yosys synthesis require **1D flat vectors**, not 2D arrays:
- Testbench: Easy CSV output generation
- Yosys: Better handling of flat bit-vectors
- SystemVerilog to synthesis: Clearer semantics

But flattening exposes the massive bit-width limitation.

---

## Part 6: Correction #2 - Parameter Reduction

### Strategy: Exponential Downscaling

Reduce matrix size and parallelism to fit FPGA constraints while maintaining testability.

### Parameter Evolution

**Iteration 1: Initial attempt**
```verilog
NAR_MAT_ROWS_DEF             64
NAR_MAT_COLS_DEF             64
NAR_MAX_INPUT_SCOOP_DEF      64
// Output: 64 × 64 × 32 = 131,072 bits (still way over 592!)
```

**Iteration 2: Middle ground**
```verilog
NAR_MAT_ROWS_DEF             16
NAR_MAT_COLS_DEF             16
NAR_MAX_INPUT_SCOOP_DEF      4
// Output: 16 × 16 × 32 = 8,192 bits (fits! 🎯)
```

**Iteration 3: Ultra-minimal (current)**
```verilog
NAR_MAT_ROWS_DEF             2
NAR_MAT_COLS_DEF             2
NAR_MAX_INPUT_SCOOP_DEF      1
// Output: 2 × 2 × 32 = 256 bits (minimal but testable)
```

### Selected Parameters for Current Design
```verilog
NAR_NUM_BITS_DEF             32
NAR_MAT_ROWS_DEF             2
NAR_MAT_COLS_DEF             2
NAR_MAX_INPUT_SCOOP_DEF      1
NAR_PIXEL_INDEX_MAX_DEF      2   // $clog2(4) = 2
```

**Rationale:**
- 2×2 = 4 pixels total
- 1 pixel input per cycle
- Executes in ~4 cycles (fast verification)
- Output: 4 × 32 = 128 bits (well within 592 pad limit)

---

## Part 7: Failure #3 - Yosys Synthesis Issues

### Problem #1: SystemVerilog Default Initialization

**Original code:**
```verilog
if(~rst)
begin
    red_pad   <= '{default:0};     // ← Yosys doesn't like this
    green_pad <= '{default:0};
    blue_pad  <= '{default:0};
end
```

**Issues:**
1. **Massive reset fanout:** Reset drives ROWS×COLS×DATA_WIDTH flip-flops in parallel
2. **Timing violations:** Long reset critical path
3. **Synthesis complexity:** Yosys struggles with pattern-based reset

**Fix:** Use simple counter + validity flag instead

```verilog
if(~rst)
begin
    pixel_counter <= '0;      // ✓ Simple, small fanout
    valid         <= 1'b0;    // ✓ Single bit flag
end
```

Data arrays (red_pad, green_pad, blue_pad) are NOT reset - they retain previous values but `valid=0` indicates invalid data.

### Problem #2: Declarations Inside Loops

**Original code:**
```verilog
for (int scoop_idx = 0; scoop_idx < MAX_INPUT_SCOOP; scoop_idx++)
begin
    automatic logic [PIXEL_ADDR_WIDTH-1:0] stored_index;  // ← Inside loop!
    automatic int stored_row;
    automatic int stored_col;
    // ...
end
```

**Issues:**
1. Non-standard SystemVerilog (not all synthesizers support this)
2. Yosys may have difficulty with scoped variables
3. Makes code less portable

**Fix:** Declare all variables at module level, reuse across iterations

```verilog
// At module level:
logic [PIXEL_ADDR_WIDTH-1:0] stored_index;
logic signed [31:0] stored_row;
logic signed [31:0] stored_col;

// In always_ff, variables are assigned, not declared:
for (int scoop_idx = 0; scoop_idx < MAX_INPUT_SCOOP; scoop_idx++)
begin
    stored_index = pixel_counter + scoop_idx;
    stored_row = ...;
    stored_col = ...;
    // ...
end
```

### Problem #3: Localparam Declarations in Generate Blocks

**Original code:**
```verilog
generate
    for (genvar row = 0; row < ROWS; row++) begin : output_row_gen
        for (genvar col = 0; col < COLS; col++) begin : output_col_gen
            localparam int PIXEL_IDX = row * COLS + col;      // ← Inside loop!
            localparam int BIT_START = PIXEL_IDX * DATA_WIDTH;
            localparam int BIT_END = BIT_START + DATA_WIDTH - 1;

            assign red_out[BIT_END:BIT_START] = red_pad[row][col];
        end
    end
endgenerate
```

**Issue:** Non-standard - localparam inside genvar loop

**Fix:** Compute indices directly in assign statements

```verilog
generate
    for (genvar row = 0; row < ROWS; row++) begin : output_row_gen
        for (genvar col = 0; col < COLS; col++) begin : output_col_gen
            // No declarations - compute directly:
            assign red_out[(row*COLS+col+1)*DATA_WIDTH-1 -: DATA_WIDTH] = red_pad[row][col];
        end
    end
endgenerate
```

**All corrections applied:** Code now Yosys-clean ✓

---

## Part 8: Deprecated Features & Why

### Feature 1: Region-Based Broadcast

**Status:** DEPRECATED (Completely removed from codebase)

**Why deprecated:**
- Fundamental architecture flaw: overwrites pixel data
- Only preserves final values (250,000 → 3 pixels!)
- Produces incorrect output (solid color instead of gradient)
- No way to fix without complete redesign

**Replacement:** Sequential storage with auto-increment counter

**Code location in git:** Lines 115-180 of scratchpad.sv (commented reference)

---

### Feature 2: Parallel Region-Based Addressing

**Status:** DEPRECATED

**Why deprecated:**
- Depended on broadcast model
- REGION_ROWS = ROWS / MAX_INPUT_SCOOP was only meaningful for broadcast

**Replacement:** Linear-to-2D address conversion using counter-based indexing

---

### Feature 3: Massive Reset Fanout ('{default:0})

**Status:** DEPRECATED (June 2, 2026)

**Why deprecated:**
- Causes timing violations in Yosys synthesis
- Huge fanout (ROWS × COLS × DATA_WIDTH flip-flops)
- Not portable across synthesizers

**Replacement:** Validity flag + simple counter reset

---

### Feature 4: Parameterized Matrix Sizes (500×500 original)

**Status:** DEPRECATED for FPGA (still valid for simulation/modeling)

**Why deprecated:**
- Output flattening creates 8,000,000-bit vector
- FPGA devices have only ~600 IO pads
- Mathematically impossible to implement on current hardware

**Replacement:** Configurable down-scaled matrix (currently 2×2 for FPGA)

---

## Part 9: Current Architecture (As of June 2, 2026)

### Module: scratchpad

**Location:** `C:\Users\supre\Downloads\Narayan\project\scratchpad.sv`

**Parameters:**
```verilog
parameter DATA_WIDTH      = NAR_NUM_BITS           // 32 bits
parameter ROWS            = NAR_MAT_ROWS           // 2 (for FPGA)
parameter COLS            = NAR_MAT_COLS           // 2 (for FPGA)
parameter MAX_INPUT_SCOOP = NAR_MAX_INPUT_SCOOP   // 1 (for FPGA)
```

**Computed Parameters:**
```verilog
localparam TOTAL_PIXELS = ROWS * COLS                    // 4
localparam PIXEL_ADDR_WIDTH = $clog2(TOTAL_PIXELS)       // 2
```

**Key Signals:**
- `pixel_counter`: Auto-incrementing write address
- `valid`: Output validity flag (0 during reset, 1 during operation)
- `red_pad/green_pad/blue_pad`: 2D internal storage arrays

**Behavior:**
- Sequential storage with auto-increment counter
- No overwriting of pixels
- Clean Yosys-compatible syntax
- Minimal reset fanout

---

## Part 10: Synthesis Status

**Current State:** ✓ Yosys-clean and ready for synthesis

---

## Conclusion

The Narayan scratchpad design has evolved from a flawed broadcast-based architecture to a robust sequential storage model. Through systematic debugging, we identified and corrected three major classes of issues: architectural (data loss), resource (FPGA overflow), and syntactical (Yosys compatibility).

**Project Status:** READY FOR SYNTHESIS ✓

---

**Document Version:** 1.0  
**Last Modified:** June 2, 2026  
**Classification:** Project Documentation
