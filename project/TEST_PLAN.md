# Scratchpad Memory (RAM) - Comprehensive Test Plan

**Test Suite:** tb_scratchpad_memory.sv  
**Compilation Script:** compile_and_sim.do  
**Total Tests:** 66  
**Clock Period:** 10ns (100MHz)

---

## Test Categories Breakdown

### 1. EASY TESTS (Tests 1-5, 10%)
**Purpose:** Verify basic read/write functionality  
**Difficulty:** Low - straightforward operations

- **E1:** Write 0xDEADBEEF to address 0
  - Verifies write operation works
  - Expected: Successful write with no errors

- **E2:** Read 0xDEADBEEF from address 0
  - Verifies data retrieved correctly
  - Expected: Output = 0xDEADBEEF

- **E3:** Write 0xCAFEBABE to address 1
  - Verifies write to different address
  - Expected: Successful write

- **E4:** Read 0xCAFEBABE from address 1
  - Verifies address 1 contains correct data
  - Expected: Output = 0xCAFEBABE

- **E5:** Verify address 0 unchanged
  - Verifies write to address 1 doesn't affect address 0
  - Expected: Address 0 still = 0xDEADBEEF

---

### 2. MEDIUM TESTS (Tests 6-10, 10%)
**Purpose:** Test boundary conditions and special patterns  
**Difficulty:** Medium - edge cases and pattern recognition

- **M1:** Write all-ZEROS pattern (0x00000000)
  - Tests zero pattern handling
  - Expected: ZEROS written successfully

- **M2:** Write all-ONES pattern (0xFFFFFFFF)
  - Tests maximum pattern handling
  - Expected: ONES written successfully

- **M3:** Read all-ZEROS pattern
  - Verifies zero data integrity
  - Expected: Output = 0x00000000

- **M4:** Read all-ONES pattern
  - Verifies maximum data integrity
  - Expected: Output = 0xFFFFFFFF

- **M5:** Write to last memory address (DEPTH-1)
  - Tests address boundary (address = ROWS×COLS-1)
  - Expected: Last address is writable

---

### 3. HARD TESTS (Tests 11-15, 10%)
**Purpose:** Stress test edge cases and design limitations  
**Difficulty:** Hard - designed to expose design flaws

- **H1:** Rapid sequential writes to different addresses
  - 5 consecutive writes with different addresses/data
  - **Design Stress:** May cause address bus contention or timing issues
  - Expected: All writes complete without corruption

- **H2:** Mode switch (write→read) on same address without address change
  - Write to address, then immediately read same address
  - **Design Stress:** May cause metastability in read/write multiplexer
  - Expected: Reads written data on next cycle

- **H3:** Rapid rw_ toggling (metastability stress)
  - Toggle rw_ signal 3 times in quick succession
  - **Design Stress:** Could cause metastable state (rw_ between 0 and 1)
  - Expected: Control signal stabilizes correctly

- **H4:** Simultaneous address and data change every cycle
  - 10 consecutive writes with changing addr AND data each cycle
  - **Design Stress:** Maximum combinational load on all inputs
  - Expected: All writes captured correctly

- **H5:** Alternating read/write with address changes
  - Rapidly switch between read/write modes while changing addresses
  - **Design Stress:** Tests input multiplexer under stress
  - Expected: Correct data routed to/from memory

---

### 4. TIMING TESTS (Tests 16-20, 10%)
**Purpose:** Violate setup/hold timing constraints  
**Difficulty:** Very Hard - intentionally breaks timing

#### Test H6: Minimal Setup Time Violation (0.5ns)
```
Clock edge occurs at 0ns
Data changes at -0.5ns (BEFORE clock by 0.5ns instead of minimum setup time)
Expected: METASTABLE DATA or INCORRECT VALUE
Design Vulnerability: May fail to capture data correctly
```

#### Test H7: Hold Time Violation (0.3ns)
```
Clock edge at 0ns
Address changed at +0.3ns (AFTER clock by only 0.3ns)
Expected: MAY capture wrong address or corrupt data
Design Vulnerability: Latch may not have settled before next write
```

#### Test H8: Control Signal at Clock Edge
```
rw_ signal changes exactly at clock edge
Design Stress: No setup/hold margin
Expected: Unpredictable behavior (read or write?)
```

#### Test H9: Chip Select Assertion During Write
```
Deselect (cs=0) for 2.5ns during active write
Reselect (cs=1) after partial write
Expected: Possible data corruption or incomplete write
Design Vulnerability: No write protection during chip deselect
```

#### Test H10: Asynchronous Reset Near Clock Edge
```
Reset assertion 3.3ns into clock cycle
Reset release 6.6ns into clock cycle
Expected: May cause asynchronous state corruption
Design Vulnerability: Reset doesn't respect synchronization
```

---

### 5. EXTENDED FUNCTIONAL TESTS (Tests 21-66, 60%)

#### EX1-EX2: Incrementing Pattern (Tests 21-40)
- Write incrementing pattern to addresses 0-9
- Read back and verify each address
- **Coverage:** Sequential address testing, read/write consistency

#### EX3-EX4: Upper Address Range (Tests 41-60)
- Write to last 10 addresses (DEPTH-10 to DEPTH-1)
- Read back and verify
- **Coverage:** Boundary condition validation

#### EX5: Chip Select Disable
- Disable chip while reading
- **Expected:** Output should be 0x00000000

#### EX6: Reset Signal
- Write data, then assert reset
- **Expected:** Output becomes 0x00000000

#### EX7: 16-Cycle Sequential Read Burst
- Continuous read operations for 16 cycles
- **Coverage:** Read performance, output stability

#### EX8: 20-Cycle Sequential Write Burst
- Continuous write operations for 20 cycles
- **Coverage:** Write throughput, address incrementation

#### EX9: Interleaved Read/Write
- Alternate between read and write operations
- **Coverage:** Mode switching, data path integrity

#### EX10: Data Persistence
- Write data, wait 10 cycles, read back
- **Coverage:** Retention, no spontaneous data corruption

---

## Test Execution Summary

### How to Run:
```bash
cd C:\Users\supre\Downloads\Narayan\project
vsim -c -do compile_and_sim.do
```

### What Happens:
1. ✓ Work library created/cleaned
2. ✓ nar_params.vh compiled
3. ✓ scratchpad_memory.sv compiled (design)
4. ✓ tb_scratchpad_memory.sv compiled (testbench)
5. ✓ Simulation runs for 5000ns
6. ✓ All 66 tests execute
7. ✓ Pass/Fail summary printed

### Expected Output:
```
Total Tests Run:     66
Tests Passed:        XX
Tests Failed:        YY
Pass Rate:          ZZ%
```

---

## Design Under Test

**Module:** scratchpad_memory.sv  
**Type:** Single-port RAM  
**Features:**
- Synchronous reads/writes (on clock edge)
- Asynchronous chip select (cs)
- Asynchronous reset (rst)
- Configurable data width (default 32-bit)
- Configurable depth (default ROWS × COLS)

**Interfaces:**
- `clk` - Clock (positive edge)
- `rst` - Async reset (active low, ~rst)
- `cs` - Chip select (active high)
- `rw_` - Read/Write control (0=write, 1=read)
- `wr_addr` - Write/Read address
- `data_in` - Input data (32-bit)
- `data_out` - Output data (32-bit)

---

## Known Limitations & Risks

### Design Issues Potentially Exposed:

1. **Metastability Risk:** Rapid rw_ toggling (H3) may cause metastable state
2. **Timing Violations:** Setup/hold violations (H6-H10) intentionally break timing
3. **Simultaneous Access:** Simultaneous addr+data changes (H4) stress combinational logic
4. **Reset Behavior:** Asynchronous reset with no synchronization (H10) is vulnerable
5. **No Write Protection:** Chip select doesn't protect ongoing writes (H9)

### Expected Failures:

- **H6-H10:** Timing tests WILL show errors (metastable states, setup/hold violations)
- These are **intentional design stress tests**, not design flaws (unless timing margins are worse than expected)

---

## Test Statistics

| Category | Tests | Difficulty | Coverage |
|----------|-------|-----------|----------|
| Easy | 5 | ★☆☆☆☆ | Basic I/O |
| Medium | 5 | ★★☆☆☆ | Boundaries |
| Hard | 5 | ★★★★☆ | Edge Cases |
| Timing | 5 | ★★★★★ | Violations |
| Extended | 46 | ★★★☆☆ | Full Coverage |
| **TOTAL** | **66** | — | Comprehensive |

---

**Document Version:** 1.0  
**Date:** June 5, 2026  
**Test Suite Status:** ✓ Ready for Execution
