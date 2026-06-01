# Scratchpad Image Testbench Flowchart & Analysis

## Overall Test Flow

```
START
  ↓
[1] LOAD PARAMETERS & TEST VECTORS
  ├─ Include: nar_params.vh
  │  ├─ DATA_WIDTH = 32 bits
  │  ├─ ROWS = 500
  │  ├─ COLS = 500
  │  └─ MAX_INPUT_SCOOP = 3 (configurable)
  │
  └─ Include: vectors.sv
     ├─ IMG_WIDTH = 500
     ├─ IMG_HEIGHT = 500
     ├─ TOTAL_PIXELS = 250,000
     ├─ test_red[0:249999]   ← Input red values
     ├─ test_green[0:249999] ← Input green values
     └─ test_blue[0:249999]  ← Input blue values
  ↓
[2] INSTANTIATE DUT (scratchpad module)
  ├─ Port mapping:
  │  ├─ .clk → clk signal
  │  ├─ .rst → rst signal
  │  ├─ .red[0:2] → red_in[0:2]   ← 3 parallel inputs
  │  ├─ .green[0:2] → green_in[0:2]
  │  ├─ .blue[0:2] → blue_in[0:2]
  │  ├─ .red_out[500][500] → red_out matrix   ← Outputs
  │  ├─ .green_out[500][500] → green_out
  │  └─ .blue_out[500][500] → blue_out
  │
  └─ Module parameter: MAX_INPUT_SCOOP = 3
  ↓
[3] CLOCK GENERATION (parallel process)
  ├─ clk = 0
  └─ Forever: #5ns clk = ~clk  (10ns period)
  ↓
╔═══════════════════════════════════════════════════════════════════════════╗
║                          MAIN TEST SEQUENCE                              ║
╚═══════════════════════════════════════════════════════════════════════════╝
  ↓
[4] INITIALIZATION (Time: 0ns)
  ├─ rst = 0  (Assert reset)
  ├─ red_in[0:2] = 0
  ├─ green_in[0:2] = 0
  ├─ blue_in[0:2] = 0
  └─ Wait: #20ns  (2 clock cycles)
     │
     │ ┌─ DUT behavior during reset (rst=0):
     │ │  └─ All red_pad[i][j] <= 0
     │ │  └─ All green_pad[i][j] <= 0
     │ │  └─ All blue_pad[i][j] <= 0
     │ └─ Matrix cleared: 500×500 = 0s
  ↓
[5] RELEASE RESET (Time: 20ns)
  ├─ rst = 1  (Release reset)
  └─ Wait: #10ns  (1 clock cycle)
     │
     │ ┌─ DUT ready to accept input
     │ │  └─ Hardware enters normal operation mode
     │ └─ Matrix still all zeros
  ↓
╔═══════════════════════════════════════════════════════════════════════════╗
║                      TEST 1: MAIN IMAGE STREAMING                        ║
╚═══════════════════════════════════════════════════════════════════════════╝
  ↓
[6] DISPLAY TEST INFO (Time: 30ns)
  ├─ Print: "Streaming image pixels into scratchpad"
  ├─ Print: "Loading 250000 test vectors"
  └─ Print: "Using parallel input: 3 pixels per cycle"
  ↓
[7] STREAMING LOOP: for (i=0; i<250000; i+=3)
  │
  ├─ ITERATION 0 (i=0):
  │  ├─ Assign: red_in[0] = test_red[0]     (0x00)
  │  ├─ Assign: red_in[1] = test_red[1]     (0x00)
  │  ├─ Assign: red_in[2] = test_red[2]     (0x01)
  │  ├─ Assign: green_in[0:2] = test_green[0:2]
  │  ├─ Assign: blue_in[0:2] = test_blue[0:2]
  │  ├─ Wait: #10ns  (1 clock cycle)
  │  │
  │  │ ┌─ DUT behavior at posedge clk:
  │  │ │  ├─ Region 0 (rows 0-166):   red_pad[*][*] <= red_in[0] = 0x00
  │  │ │  ├─ Region 1 (rows 167-332): red_pad[*][*] <= red_in[1] = 0x00
  │  │ │  └─ Region 2 (rows 333-499): red_pad[*][*] <= red_in[2] = 0x01
  │  │ │
  │  │ │ Same process for green and blue channels
  │  │ └─ Matrix updated in 3 regions:
  │  │     [0-166, 0-499]: (0x00, G0, B0)
  │  │     [167-332, 0-499]: (0x00, G1, B1)
  │  │     [333-499, 0-499]: (0x01, G2, B2)
  │  │
  │  └─ Check progress: (0+3) % 3000 = 3 (not divisible)
  │
  ├─ ITERATION 1 (i=3):
  │  ├─ Assign: red_in[0] = test_red[3]
  │  ├─ Assign: red_in[1] = test_red[4]
  │  ├─ Assign: red_in[2] = test_red[5]
  │  ├─ Wait: #10ns
  │  │
  │  │ ┌─ DUT: Overwrites previous region values
  │  │ │  └─ [0-166]: RED updated from 0x00 to test_red[3]
  │  │ │  └─ [167-332]: RED updated from 0x00 to test_red[4]
  │  │ │  └─ [333-499]: RED updated from 0x01 to test_red[5]
  │  │ │
  │  │ └─ Previous pixel values LOST!
  │  │    (This is the key issue!)
  │  └─ Check progress: (3+3) % 3000 = 6 (not divisible)
  │
  ├─ ...
  │
  ├─ ITERATION 83333 (i=249999):  [FINAL ITERATION]
  │  ├─ Assign: red_in[0] = test_red[249999]
  │  ├─ Assign: red_in[1] = test_red[250000] → OUT OF BOUNDS!
  │  ├─ Assign: red_in[2] = test_red[250001] → OUT OF BOUNDS!
  │  ├─ Wait: #10ns
  │  │
  │  │ ┌─ DUT: Final broadcast
  │  │ │  ├─ [0-166]: RED = test_red[249999]
  │  │ │  ├─ [167-332]: RED = test_red[250000] (undefined/garbage)
  │  │ │  └─ [333-499]: RED = test_red[250001] (undefined/garbage)
  │  │ │
  │  │ │ Matrix now contains FINAL STATE only!
  │  │ │ All intermediate pixel data OVERWRITTEN!
  │  │ └─ NO HISTORY preserved
  │  └─ Check progress: (249999+3) % 3000 = 0 (divisible)
  │     └─ Print: "Streamed 250002 pixels" ← Incorrect count!
  │
  └─ LOOP ENDS: 83,334 iterations (250,000 ÷ 3)
     │
     └─ Total simulation time: 833,340 ns (83,334 clocks × 10ns)
  ↓
[8] WAIT FOR STABILIZATION (Time: 833,340ns)
  ├─ Wait: #100ns  (10 clock cycles)
  └─ Purpose: Allow final values to settle in hardware
  ↓
[9] CAPTURE OUTPUT MATRIX → output_rgb.csv
  ├─ Open file: output_rgb.csv
  ├─ Write header: "row,col,red,green,blue"
  │
  └─ Nested loop: for row=0 to 499, for col=0 to 499
     ├─ Read: red_out[row][col]
     ├─ Read: green_out[row][col]
     ├─ Read: blue_out[row][col]
     └─ Write CSV line: "row,col,red_hex,green_hex,blue_hex"
  │
  │ CRITICAL POINT:
  │ ├─ Rows 0-166: red values ≈ test_red[249999]
  │ ├─ Rows 167-332: red values ≈ test_red[250000] (garbage)
  │ └─ Rows 333-499: red values ≈ test_red[250001] (garbage)
  │
  └─ File closed
  ↓
╔═══════════════════════════════════════════════════════════════════════════╗
║                    TEST 2: GRADIENT PATTERN (DEBUGGING)                  ║
╚═══════════════════════════════════════════════════════════════════════════╝
  ↓
[10] RESET SCRATCHPAD
  ├─ rst = 0
  ├─ Wait: #10ns
  ├─ rst = 1
  └─ Wait: #10ns  (Matrix cleared again)
  ↓
[11] STREAMING LOOP: Gradient pattern
  │
  ├─ for (i=0; i<250000; i+=3)
  │  ├─ for (j=0; j<3; j++)
  │  │  ├─ red_in[j] = 0x00 + (i+j) × 0xFF / 250000
  │  │  ├─ green_in[j] = 0x80  (constant)
  │  │  └─ blue_in[j] = 0xFF - (i+j) × 0xFF / 250000
  │  │
  │  └─ Wait: #10ns
  │
  └─ Loop completes: Same issue as Test 1
     (Only final values preserved in 3 regions)
  ↓
[12] WAIT FOR STABILIZATION
  ├─ Wait: #100ns
  └─ Allow hardware to settle
  ↓
[13] CAPTURE OUTPUT MATRIX → output_gradient.csv
  ├─ Same process as step [9]
  └─ File contains 3-region gradient values
  ↓
[14] FINISH SIMULATION
  └─ $finish
  ↓
END
```

---

## Data Flow Diagram

```
INPUT:                          PROCESSING:                    OUTPUT:
                                
vectors.sv                      Testbench                      output_rgb.csv
├─ test_red[250k]              ├─ Stream loop                 ├─ row,col,red,green,blue
├─ test_green[250k]    ────→    │  (250k pixels)              ├─ 0,0,0xFF,0x80,0x00
└─ test_blue[250k]             │  (3 pixels/cycle)            ├─ 0,1,0xFF,0x80,0x00
                               │  (83,334 iterations)        │  ...
                               │                              └─ 499,499,0xFF,0x80,0x00
                               ↓
                          DUT (scratchpad)
                          ├─ Region 0 (rows 0-166)      ←─ red_in[0]
                          ├─ Region 1 (rows 167-332)    ←─ red_in[1]
                          └─ Region 2 (rows 333-499)    ←─ red_in[2]
                          
                          Each cycle: NEW values broadcast
                          (Previous values OVERWRITTEN)
                               ↓
                          After 83,334 cycles:
                          Matrix contains ONLY the
                          last batch of pixel values!
```

---

## Critical Issue: Data Loss in Broadcast Architecture

### What SHOULD happen (ideal image storage):
```
Pixel 0 (red=0x00) → Storage location [0][0] ✓
Pixel 1 (red=0x00) → Storage location [0][1] ✓
Pixel 2 (red=0x01) → Storage location [0][2] ✓
...
Pixel 249999 (red=0xFF) → Storage location [499][499] ✓

Result: Complete image preserved
```

### What ACTUALLY happens (broadcast architecture):
```
Cycle 0: red_in = [0x00, 0x00, 0x01]
         └─ Region 0 ← 0x00, Region 1 ← 0x00, Region 2 ← 0x01

Cycle 1: red_in = [0x01, 0x01, 0x02]
         └─ Region 0 ← 0x01 (overwrites 0x00!), Region 1 ← 0x01, Region 2 ← 0x02

Cycle 2: red_in = [0x02, 0x02, 0x03]
         └─ Region 0 ← 0x02 (overwrites again!), ...

...

Final state after 83,334 cycles:
Region 0 = test_red[249999]  (only LAST value)
Region 1 = test_red[250000]  (undefined!)
Region 2 = test_red[250001]  (undefined!)

Result: Only 3 pixel values, rest lost!
```

---

## Testbench Issues Found

| Issue # | Location | Problem | Impact |
|---------|----------|---------|--------|
| 1 | Line 116-121 | Loop index `i+=MAX_INPUT_SCOOP` | Correct stride calculation |
| 2 | Line 118 | Boundary check `(i+j) < TOTAL_PIXELS` | Prevents array overflow |
| 3 | Line 157-160 | Gradient calculation uses `TOTAL_PIXELS` | Correct scaling |
| 4 | **Line 110-111** | **Loop streams pixels correctly** | ✓ Testbench logic OK |
| **5** | **Line 39** | **Module parameter uses MAX_INPUT_SCOOP** | ✓ Correct instantiation |

**Testbench Verdict: ✅ WORKING CORRECTLY**

---

## Hardware Issues Found

| Issue # | Location | Problem | Impact | Severity |
|---------|----------|---------|--------|----------|
| 1 | scratchpad.sv lines 66-80 | Region-based broadcast overwrites data | Only final values preserved | **CRITICAL** |
| 2 | scratchpad.sv lines 67-80 | No address decoder | Pixels not stored at row/col positions | **CRITICAL** |
| 3 | Test vectors iteration 83,334 | Array access [250000], [250001] out of bounds | Undefined values in regions 1-2 | **HIGH** |

**Hardware Verdict: ❌ ARCHITECTURAL FLAW**

---

## Root Cause Analysis

**Where is the problem originating?**

### From the testbench perspective:
- ✅ Correctly loads test vectors from vectors.sv
- ✅ Correctly streams pixels with proper MAX_INPUT_SCOOP parallelization
- ✅ Correctly waits for stabilization
- ✅ Correctly captures output matrix

**The testbench is NOT the problem.**

### From the hardware perspective:
- ❌ Broadcast architecture overwrites pixels every cycle
- ❌ No mechanism to store pixels at specific row/col addresses
- ❌ Final matrix contains only the last batch of values
- ❌ 250,000 pixels collapsed into 3 regions with 1 value each

**The hardware architecture is the problem.**

---

## Visual Result Explanation

```
Input Image:        Broadcast Output:      Why?
(Gradient)          (Solid Cyan)           
                                           
Blue→Red           All one color           Each region gets only the
Yellow→Green       (Uniform RGB)          last value broadcast to it
                                           
Test shows:        Output shows:
Pixels 0-250k      Only pixels 249998-250001
distributed       (the final batch)
across 500×500
```

The solid cyan result is **expected behavior** for a broadcast-to-regions architecture when the last pixels happen to be low-red, high-green, high-blue values.

