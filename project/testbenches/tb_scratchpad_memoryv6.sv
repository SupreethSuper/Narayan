`timescale 1ns/1ps
`include "nar_params.vh"

// ============================================================
// Timing macros  (inherited from v5, unchanged)
// ============================================================
`define CLK_PERIOD_DEF   \
    begin                \
    @(posedge clk);      \
    @(negedge clk);      \
    end

// Active-low async rst: wait 1 clk, assert, wait 1 clk, deassert, wait 1 clk
`define RESET       \
    begin           \
    `CLK_PERIOD_DEF \
    rst = 1'b0;     \
    `CLK_PERIOD_DEF \
    rst = 1'b1;     \
    `CLK_PERIOD_DEF \
    end

`define READ        \
    begin           \
    `CLK_PERIOD_DEF \
    rw_ = 1'b1;     \
    `CLK_PERIOD_DEF \
    end

`define WRITE       \
    begin           \
    `CLK_PERIOD_DEF \
    rw_ = 1'b0;     \
    `CLK_PERIOD_DEF \
    end

`define RESET_READ_TRANS  \
    begin `RESET `READ end

`define RESET_WRITE_TRANS \
    begin `RESET `WRITE end

`define WRITE_RESET_TRANS \
    begin `WRITE `RESET end

`define WRITE_READ_TRANS  \
    begin `WRITE `READ end

`define READ_RESET_TRANS  \
    begin `READ `RESET end

`define READ_WRITE_TRANS  \
    begin `READ `WRITE end

`define CS_OFF \
    begin `CLK_PERIOD_DEF cs = 1'b0; end

`define CS_ON \
    begin `CLK_PERIOD_DEF cs = 1'b1; end

// Write addr then data (5 clocks total).
// Requires FSM already in or transitioning to WRITE_STATE via `WRITE inside.
`define WRITE_TO(addr, data) \
    begin                    \
    `CLK_PERIOD_DEF          \
    `WRITE                   \
    wr_addr = addr;          \
    `CLK_PERIOD_DEF          \
    data_in = data;          \
    `CLK_PERIOD_DEF          \
    end

// Set read address then clock once so read port captures (3 clocks total).
`define READ_FROM(addr) \
    begin               \
    `CLK_PERIOD_DEF     \
    `READ               \
    wr_addr = addr;     \
    `CLK_PERIOD_DEF     \
    end

// ============================================================
// NEW macros for v6
// ============================================================

// Drive all inputs to known safe values then issue a hardware reset.
// Leaves: rst=1 rw_=1 cs=1 wr_addr=0 data_in=0  FSM=READ_STATE
`define FULL_RESET    \
    begin             \
    rst     = 1'b1;   \
    rw_     = 1'b1;   \
    cs      = 1'b1;   \
    wr_addr = '0;     \
    data_in = '0;     \
    `RESET            \
    end

// ============================================================
module tb_scratchpad_memory_v6;

    // --------------------------------------------------------
    // Parameters
    // --------------------------------------------------------
    localparam DATA_WIDTH  = NAR_NUM_BITS;       // 32
    localparam ROWS        = NAR_MAT_ROWS;       // 5
    localparam COLS        = NAR_MAT_COLS;       // 5
    localparam MEM_ADDRESS = $clog2(ROWS * COLS);// 5
    localparam DEPTH       = ROWS * COLS;        // 25
    localparam CLK_PERIOD  = 10;

    // --------------------------------------------------------
    // Signals
    // --------------------------------------------------------
    logic clk;
    logic rst;
    logic rw_;
    logic cs;
    logic [MEM_ADDRESS-1:0] wr_addr;
    logic [DATA_WIDTH-1:0]  data_in;
    logic [DATA_WIDTH-1:0]  data_out;

    integer test_count = 0;
    integer pass_count = 0;
    integer fail_count = 0;

    // --------------------------------------------------------
    // DUT
    // --------------------------------------------------------
    scratchpad_memory #(
        .DATA_WIDTH (DATA_WIDTH),
        .ROWS       (ROWS),
        .COLS       (COLS),
        .MEM_ADDRESS(MEM_ADDRESS)
    ) dut (
        .clk     (clk),
        .rst     (rst),
        .rw_     (rw_),
        .cs      (cs),
        .wr_addr (wr_addr),
        .data_in (data_in),
        .data_out(data_out)
    );

    // --------------------------------------------------------
    // Clock
    // --------------------------------------------------------
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // --------------------------------------------------------
    // Waveform dump
    // --------------------------------------------------------
    initial begin
        $dumpfile("tb_scratchpad_memory_v6.vcd");
        $dumpvars(0, tb_scratchpad_memory_v6);
    end

    // --------------------------------------------------------
    // Checker tasks
    // --------------------------------------------------------
    task automatic test_pass(string name);
        pass_count++;
        test_count++;
        $display("[PASS] T%03d: %s", test_count, name);
    endtask

    task automatic test_fail(string name, string reason);
        fail_count++;
        test_count++;
        $display("[FAIL] T%03d: %s  |  %s", test_count, name, reason);
    endtask

    // Use !== so X comparisons work correctly
    task automatic chk(
        logic [DATA_WIDTH-1:0] expected,
        logic [DATA_WIDTH-1:0] actual,
        string name
    );
        if (expected !== actual)
            test_fail(name, $sformatf("exp=0x%08h  got=0x%08h", expected, actual));
        else
            test_pass(name);
    endtask

    // ============================================================
    //  TESTS
    // ============================================================
    initial begin

        // ── Initialise all inputs ─────────────────────────────────
        rst     = 1'b1;
        rw_     = 1'b1;
        cs      = 1'b1;
        wr_addr = '0;
        data_in = '0;
        `RESET

        $display("====================================================");
        $display("  scratchpad_memory  Transition Test Suite  v6");
        $display("  ROWS=%0d  COLS=%0d  DATA=%0d-bit  ADDR=%0d-bit",
                 ROWS, COLS, DATA_WIDTH, MEM_ADDRESS);
        $display("====================================================");

        // ══════════════════════════════════════════════════════════
        // GROUP 0 ─ ORIGINAL v5 TESTS (T1-T3)
        // ══════════════════════════════════════════════════════════

        // T1: CS off blocks all writes
        `RESET
        `CS_OFF
        `RESET_WRITE_TRANS
        `WRITE_TO(5'h15, 32'hDEAD_BEEF)
        `WRITE_READ_TRANS
        `READ_FROM(5'h15)
        chk(32'h0000_0000, data_out, "CS_OFF write blocked, read=0");

        // T2: Basic write then read
        `FULL_RESET
        `CS_ON
        `RESET_WRITE_TRANS
        `WRITE_TO(5'h15, 32'hDEAD_BEEF)
        `WRITE_READ_TRANS
        `READ_FROM(5'h15)
        chk(32'hDEAD_BEEF, data_out, "CS_ON basic write/read");

        // T3: Read different address (never written)
        `FULL_RESET
        `CS_ON
        `RESET_WRITE_TRANS
        `WRITE_TO(5'h15, 32'hFACA_CACA)
        `WRITE_READ_TRANS
        `READ_FROM(5'h10)
        chk(32'h0000_0000, data_out, "Read unwritten address returns 0");

        // ══════════════════════════════════════════════════════════
        // GROUP A ─ CHIP SELECT EDGE CASES (T4-T8)
        // ══════════════════════════════════════════════════════════

        // T4: Write succeeds, then CS pulse low forces RESET_STATE, then read → 0
        `FULL_RESET
        `CS_ON
        `RESET_WRITE_TRANS
        `WRITE_TO(5'h0A, 32'hCAFE_BABE)
        `CS_OFF           // CS=0: FSM → RESET_STATE next clock
        `CLK_PERIOD_DEF   // let FSM land in RESET_STATE
        `CS_ON
        `WRITE_READ_TRANS
        `READ_FROM(5'h0A)
        chk(32'h0000_0000, data_out, "CS pulse low wipes FSM state, read=0");

        // T5: CS=0 the whole write session; CS=1 then read → 0
        `FULL_RESET
        `CS_OFF
        `RESET_WRITE_TRANS
        `WRITE_TO(5'h02, 32'h1234_5678)
        `CS_ON
        `WRITE_READ_TRANS
        `READ_FROM(5'h02)
        chk(32'h0000_0000, data_out, "CS=0 entire write, read after CS=1 → 0");

        // T6: CS falls low between addr and data_in (mid-write abort)
        `FULL_RESET
        `CS_ON
        `RESET_WRITE_TRANS
        `CLK_PERIOD_DEF
        `WRITE
        wr_addr = 5'h03;
        `CLK_PERIOD_DEF
        cs      = 1'b0;        // yank CS before data_in committed
        data_in = 32'hBAD0_CAFE;
        `CLK_PERIOD_DEF
        cs      = 1'b1;
        `WRITE_READ_TRANS
        `READ_FROM(5'h03)
        chk(32'h0000_0000, data_out, "CS low mid-write aborts the write");

        // T7: CS falls during READ_STATE
        `FULL_RESET
        `CS_ON
        `RESET_WRITE_TRANS
        `WRITE_TO(5'h04, 32'hAAAA_BBBB)
        `WRITE_READ_TRANS        // now in READ_STATE
        `CS_OFF                  // pull CS while reading
        `READ_FROM(5'h04)
        chk(32'h0000_0000, data_out, "CS low during READ forces data_out=0");

        // T8: Toggle CS off then back on mid-READ, verify data gone
        `FULL_RESET
        `CS_ON
        `RESET_WRITE_TRANS
        `WRITE_TO(5'h05, 32'h1111_2222)
        `WRITE_READ_TRANS
        `READ_FROM(5'h05)
        chk(32'h1111_2222, data_out, "Read value before CS toggle");
        `CS_OFF
        `CS_ON
        `READ_FROM(5'h05)
        chk(32'h0000_0000, data_out, "CS toggled during READ, then read again → 0");

        // ══════════════════════════════════════════════════════════
        // GROUP B ─ FSM STATE TRANSITION PAIRS (T9-T20)
        // ══════════════════════════════════════════════════════════

        // T9: RESET→READ with no prior write (clear_all=1 locks output to 0)
        `FULL_RESET
        `CS_ON
        `RESET_READ_TRANS
        `READ_FROM(5'h00)
        chk(32'h0000_0000, data_out, "RESET→READ no prior write → 0 (clear_all=1)");

        // T10: RESET→WRITE→RESET→READ: second reset clears clear_all back to 1
        `FULL_RESET
        `CS_ON
        `RESET_WRITE_TRANS
        `WRITE_TO(5'h01, 32'hDEAD_C0DE)
        `WRITE_RESET_TRANS
        `RESET_READ_TRANS
        `READ_FROM(5'h01)
        chk(32'h0000_0000, data_out, "Write, reset, read → 0 (second RESET wipes clear_all)");

        // T11a/b: WRITE→READ→WRITE overwrite same address
        `FULL_RESET
        `CS_ON
        `RESET_WRITE_TRANS
        `WRITE_TO(5'h06, 32'hAAAA_AAAA)
        `WRITE_READ_TRANS
        `READ_FROM(5'h06)
        chk(32'hAAAA_AAAA, data_out, "W→R→W: first write value");
        `READ_WRITE_TRANS
        `WRITE_TO(5'h06, 32'hBBBB_BBBB)
        `WRITE_READ_TRANS
        `READ_FROM(5'h06)
        chk(32'hBBBB_BBBB, data_out, "W→R→W: overwrite with new value");

        // T12: WRITE→WRITE same address back-to-back (no READ in between)
        `FULL_RESET
        `CS_ON
        `RESET_WRITE_TRANS
        `WRITE_TO(5'h07, 32'h1111_1111)
        `WRITE_TO(5'h07, 32'h2222_2222)
        `WRITE_READ_TRANS
        `READ_FROM(5'h07)
        chk(32'h2222_2222, data_out, "Back-to-back WRITE same addr, last value wins");

        // T13a/b: READ→WRITE→READ: overwrite via R→W→R path
        `FULL_RESET
        `CS_ON
        `RESET_WRITE_TRANS
        `WRITE_TO(5'h08, 32'hCCCC_CCCC)
        `WRITE_READ_TRANS
        `READ_FROM(5'h08)
        chk(32'hCCCC_CCCC, data_out, "R→W→R: read before overwrite");
        `READ_WRITE_TRANS
        `WRITE_TO(5'h08, 32'hDDDD_DDDD)
        `WRITE_READ_TRANS
        `READ_FROM(5'h08)
        chk(32'hDDDD_DDDD, data_out, "R→W→R: read after overwrite");

        // T14a/b/c: Sustained READ_STATE — data_out holds across multiple reads
        `FULL_RESET
        `CS_ON
        `RESET_WRITE_TRANS
        `WRITE_TO(5'h09, 32'hEEEE_EEEE)
        `WRITE_READ_TRANS
        `READ_FROM(5'h09)
        chk(32'hEEEE_EEEE, data_out, "Sustained READ: first read");
        `READ_FROM(5'h09)
        chk(32'hEEEE_EEEE, data_out, "Sustained READ: second read (no intervening write)");
        `READ_FROM(5'h09)
        chk(32'hEEEE_EEEE, data_out, "Sustained READ: third read");

        // T15a/b: WRITE→READ→RESET→READ  — reset zeroes data_out
        `FULL_RESET
        `CS_ON
        `RESET_WRITE_TRANS
        `WRITE_TO(5'h0B, 32'hF0F0_F0F0)
        `WRITE_READ_TRANS
        `READ_FROM(5'h0B)
        chk(32'hF0F0_F0F0, data_out, "W→R→RST→R: read before reset");
        `READ_RESET_TRANS
        `RESET_READ_TRANS
        `READ_FROM(5'h0B)
        chk(32'h0000_0000, data_out, "W→R→RST→R: data_out=0 after reset");

        // T16: WRITE hold — 4 consecutive writes same addr, last wins
        `FULL_RESET
        `CS_ON
        `RESET_WRITE_TRANS
        `WRITE_TO(5'h0C, 32'hAAAA_0000)
        `WRITE_TO(5'h0C, 32'hBBBB_0000)
        `WRITE_TO(5'h0C, 32'hCCCC_0000)
        `WRITE_TO(5'h0C, 32'hDDDD_0000)
        `WRITE_READ_TRANS
        `READ_FROM(5'h0C)
        chk(32'hDDDD_0000, data_out, "4 consecutive writes same addr: last value");

        // T17: Write two different addresses, read both back independently
        `FULL_RESET
        `CS_ON
        `RESET_WRITE_TRANS
        `WRITE_TO(5'h0D, 32'h1234_0000)
        `WRITE_TO(5'h0E, 32'h5678_0000)
        `WRITE_READ_TRANS
        `READ_FROM(5'h0D)
        chk(32'h1234_0000, data_out, "Two-addr: read addr A");
        `READ_FROM(5'h0E)
        chk(32'h5678_0000, data_out, "Two-addr: read addr B");

        // T18: WRITE_STATE hold — data_out freezes (does not update in WRITE_STATE)
        `FULL_RESET
        `CS_ON
        `RESET_WRITE_TRANS
        `WRITE_TO(5'h0F, 32'h9999_9999)
        `WRITE_READ_TRANS
        `READ_FROM(5'h0F)
        chk(32'h9999_9999, data_out, "data_out before re-entering WRITE");
        // Go back to WRITE with a different value — data_out must not change
        `READ_WRITE_TRANS
        `CLK_PERIOD_DEF
        wr_addr = 5'h0F;
        data_in = 32'hDEAD_DEAD;   // put different data on the bus
        `CLK_PERIOD_DEF
        // Still in WRITE_STATE — data_out must hold previous read value
        chk(32'h9999_9999, data_out, "WRITE_STATE: data_out frozen (holds last READ value)");

        // T19: WRITE→READ different addresses simultaneously (aliasing test)
        `FULL_RESET
        `CS_ON
        `RESET_WRITE_TRANS
        `WRITE_TO(5'h10, 32'hABCD_EF01)
        `WRITE_TO(5'h11, 32'h0123_4567)
        `WRITE_TO(5'h12, 32'hDEAD_FEED)
        `WRITE_READ_TRANS
        `READ_FROM(5'h12)
        chk(32'hDEAD_FEED, data_out, "3-addr: read addr 0x12");
        `READ_FROM(5'h10)
        chk(32'hABCD_EF01, data_out, "3-addr: read addr 0x10");
        `READ_FROM(5'h11)
        chk(32'h0123_4567, data_out, "3-addr: read addr 0x11");

        // T20: READ→READ changing address between reads
        `FULL_RESET
        `CS_ON
        `RESET_WRITE_TRANS
        `WRITE_TO(5'h00, 32'hAAAA_0000)
        `WRITE_TO(5'h01, 32'hBBBB_0001)
        `WRITE_TO(5'h02, 32'hCCCC_0002)
        `WRITE_READ_TRANS
        `READ_FROM(5'h01)
        chk(32'hBBBB_0001, data_out, "Multi-read: addr 0x01");
        `READ_FROM(5'h00)
        chk(32'hAAAA_0000, data_out, "Multi-read: addr 0x00");
        `READ_FROM(5'h02)
        chk(32'hCCCC_0002, data_out, "Multi-read: addr 0x02");

        // ══════════════════════════════════════════════════════════
        // GROUP C ─ ADDRESS BOUNDARY (T21-T24)
        // ══════════════════════════════════════════════════════════

        // T21: Minimum valid address (0)
        `FULL_RESET
        `CS_ON
        `RESET_WRITE_TRANS
        `WRITE_TO(5'h00, 32'hABCD_0000)
        `WRITE_READ_TRANS
        `READ_FROM(5'h00)
        chk(32'hABCD_0000, data_out, "Addr 0 (min valid): write/read");

        // T22: Maximum valid address (24 = 0x18)
        `FULL_RESET
        `CS_ON
        `RESET_WRITE_TRANS
        `WRITE_TO(5'h18, 32'h0000_ABCD)
        `WRITE_READ_TRANS
        `READ_FROM(5'h18)
        chk(32'h0000_ABCD, data_out, "Addr 24/0x18 (max valid): write/read");

        // T23: First OOB address (25 = 0x19, row=5 → out of bounds)
        //      Expect X or 0 — logged as INFO, not pass/fail
        `FULL_RESET
        `CS_ON
        `RESET_WRITE_TRANS
        `WRITE_TO(5'h19, 32'hDEAD_DEAD)
        `WRITE_READ_TRANS
        `READ_FROM(5'h19)
        begin
            test_count++;
            $display("[INFO] T%03d: OOB addr 25 (0x19), data_out=0x%08h  [expect X or 0]",
                     test_count, data_out);
            if (^data_out === 1'bx)
                $display("         → contains X bits (uninitialized memory, expected)");
        end

        // T24: Max 5-bit OOB address (31 = 0x1F, row=6 → out of bounds)
        `FULL_RESET
        `CS_ON
        `RESET_WRITE_TRANS
        `WRITE_TO(5'h1F, 32'hBEEF_BEEF)
        `WRITE_READ_TRANS
        `READ_FROM(5'h1F)
        begin
            test_count++;
            $display("[INFO] T%03d: OOB addr 31 (0x1F), data_out=0x%08h  [expect X or 0]",
                     test_count, data_out);
            if (^data_out === 1'bx)
                $display("         → contains X bits (uninitialized memory, expected)");
        end

        // ══════════════════════════════════════════════════════════
        // GROUP D ─ DATA PATTERNS (T25-T28)
        // ══════════════════════════════════════════════════════════

        // T25: Write 0x00000000 (zero), read back
        `FULL_RESET
        `CS_ON
        `RESET_WRITE_TRANS
        `WRITE_TO(5'h13, 32'h0000_0000)
        `WRITE_READ_TRANS
        `READ_FROM(5'h13)
        chk(32'h0000_0000, data_out, "Data 0x00000000 round-trip");

        // T26: Write 0xFFFFFFFF (all ones)
        `FULL_RESET
        `CS_ON
        `RESET_WRITE_TRANS
        `WRITE_TO(5'h14, 32'hFFFF_FFFF)
        `WRITE_READ_TRANS
        `READ_FROM(5'h14)
        chk(32'hFFFF_FFFF, data_out, "Data 0xFFFFFFFF round-trip");

        // T27: Alternating 10 pattern
        `FULL_RESET
        `CS_ON
        `RESET_WRITE_TRANS
        `WRITE_TO(5'h15, 32'hAAAA_AAAA)
        `WRITE_READ_TRANS
        `READ_FROM(5'h15)
        chk(32'hAAAA_AAAA, data_out, "Data 0xAAAAAAAA round-trip");

        // T28: Alternating 01 pattern
        `FULL_RESET
        `CS_ON
        `RESET_WRITE_TRANS
        `WRITE_TO(5'h16, 32'h5555_5555)
        `WRITE_READ_TRANS
        `READ_FROM(5'h16)
        chk(32'h5555_5555, data_out, "Data 0x55555555 round-trip");

        // ══════════════════════════════════════════════════════════
        // GROUP E ─ check_zero APPROXIMATION (T29)
        // ══════════════════════════════════════════════════════════
        //
        // check_zero_rows[r] and check_zero_cols[c] are set per-row and
        // per-column, NOT per-cell. Writing (r=0,c=0)=addr 0 and
        // (r=1,c=1)=addr 6 marks rows[0,1] and cols[0,1]. Reading
        // addr 1 (r=0,c=1) then passes the gate — but memory[0][1]
        // was NEVER written, so data_out will be X or stale.
        //
        `FULL_RESET
        `CS_ON
        `RESET_WRITE_TRANS
        `WRITE_TO(5'h00, 32'hDEAD_0000)   // (row=0, col=0)
        `WRITE_TO(5'h06, 32'h0000_BEEF)   // (row=1, col=1)
        `WRITE_READ_TRANS
        `READ_FROM(5'h01)                   // (row=0, col=1) — NEVER written
        begin
            test_count++;
            $display("[BUG]  T%03d: check_zero approx — reading unwritten cell (r=0,c=1)/addr1",
                     test_count);
            $display("         data_out=0x%08h", data_out);
            if (^data_out === 1'bx) begin
                fail_count++;
                $display("         FAIL → X leaked through check_zero gate (uninitialized cell)");
            end else if (data_out !== 32'h0) begin
                fail_count++;
                $display("         FAIL → non-zero stale value from unwritten cell");
            end else begin
                pass_count++;
                $display("         PASS → coincidentally zero (uninit defaulted to 0)");
            end
        end

        // ══════════════════════════════════════════════════════════
        // GROUP F ─ MULTI-LOCATION SWEEPS (T30-T55)
        // ══════════════════════════════════════════════════════════

        // T30-T34: Write all 5 addresses in row 0 (addrs 0-4), read all back
        `FULL_RESET
        `CS_ON
        `RESET_WRITE_TRANS
        `WRITE_TO(5'h00, 32'hA000_0000)
        `WRITE_TO(5'h01, 32'hA000_0001)
        `WRITE_TO(5'h02, 32'hA000_0002)
        `WRITE_TO(5'h03, 32'hA000_0003)
        `WRITE_TO(5'h04, 32'hA000_0004)
        `WRITE_READ_TRANS
        `READ_FROM(5'h00) chk(32'hA000_0000, data_out, "Row0 sweep: addr 0");
        `READ_FROM(5'h01) chk(32'hA000_0001, data_out, "Row0 sweep: addr 1");
        `READ_FROM(5'h02) chk(32'hA000_0002, data_out, "Row0 sweep: addr 2");
        `READ_FROM(5'h03) chk(32'hA000_0003, data_out, "Row0 sweep: addr 3");
        `READ_FROM(5'h04) chk(32'hA000_0004, data_out, "Row0 sweep: addr 4");

        // T35-T59: Full 25-address sweep
        //   Write phase: stay in WRITE_STATE, set addr then data each 2 clocks
        //   Read  phase: stay in READ_STATE,  set addr each 1 clock
        `FULL_RESET
        `CS_ON
        `RESET_WRITE_TRANS   // leaves rw_=0, FSM=WRITE_STATE

        begin : write_sweep
            for (int i = 0; i < DEPTH; i++) begin
                // addr arrives first; data arrives one clock later
                wr_addr = i[MEM_ADDRESS-1:0];
                @(posedge clk); @(negedge clk);     // write fires with old data_in
                data_in = (32'hC0DE_0000 | i[DATA_WIDTH-1:0]);
                @(posedge clk); @(negedge clk);     // write fires with correct data_in
            end
        end

        // Transition to READ_STATE
        rw_ = 1'b1;
        @(posedge clk); @(negedge clk);  // next_fsm_state = READ_STATE
        @(posedge clk); @(negedge clk);  // fsm_state = READ_STATE

        begin : read_sweep
            for (int i = 0; i < DEPTH; i++) begin
                wr_addr = i[MEM_ADDRESS-1:0];
                @(posedge clk); @(negedge clk);  // read port captures
                chk(32'hC0DE_0000 | i[DATA_WIDTH-1:0], data_out,
                    $sformatf("Full sweep addr %0d", i));
            end
        end

        // ══════════════════════════════════════════════════════════
        // GROUP G ─ ASYNC RESET (T60-T62)
        // ══════════════════════════════════════════════════════════

        // T60: data_out must go to 0 immediately on async rst assertion
        //      (does not wait for posedge clk — driven by negedge rst)
        `FULL_RESET
        `CS_ON
        `RESET_WRITE_TRANS
        `WRITE_TO(5'h17, 32'hFACE_CAFE)
        `WRITE_READ_TRANS
        `READ_FROM(5'h17)
        chk(32'hFACE_CAFE, data_out, "Async rst setup: value readable before reset");
        // Assert rst asynchronously (not clock-aligned)
        @(negedge clk);
        #(CLK_PERIOD * 0.3);   // 30% into the low phase — not at an edge
        rst = 1'b0;
        #1;                     // let async combinational settle
        chk(32'h0000_0000, data_out, "Async rst: data_out=0 within 1ns of rst assertion");

        // T61: After async reset releases, state is clean, read returns 0
        rst = 1'b1;
        `CLK_PERIOD_DEF
        `WRITE_READ_TRANS
        `READ_FROM(5'h17)
        chk(32'h0000_0000, data_out, "After async rst release, clear_all=1, read=0");

        // T62: Async reset in middle of write (addr set, data_in not yet committed)
        `FULL_RESET
        `CS_ON
        `RESET_WRITE_TRANS
        `CLK_PERIOD_DEF
        rw_     = 1'b0;
        wr_addr = 5'h18;
        @(posedge clk); @(negedge clk);  // FSM enters WRITE_STATE
        data_in = 32'hBEEF_BABE;
        // Mid-write: assert rst before the next posedge commits
        #(CLK_PERIOD * 0.2);
        rst = 1'b0;
        #1;
        chk(32'h0000_0000, data_out, "Async rst mid-write: data_out immediately 0");
        rst = 1'b1;
        `CLK_PERIOD_DEF
        `WRITE_READ_TRANS
        `READ_FROM(5'h18)
        chk(32'h0000_0000, data_out, "Addr after mid-write rst: should NOT have been committed");

        // ══════════════════════════════════════════════════════════
        // GROUP H ─ RAPID rw_ TOGGLING (T63-T64)
        // ══════════════════════════════════════════════════════════

        // T63: Write a known value, then toggle rw_ every clock 10 times, verify data intact
        `FULL_RESET
        `CS_ON
        `RESET_WRITE_TRANS
        `WRITE_TO(5'h13, 32'hDEAD_1234)
        begin : toggle_block
            for (int k = 0; k < 10; k++) begin
                @(posedge clk); @(negedge clk);
                rw_ = ~rw_;
            end
        end
        // Settle into READ
        `WRITE_READ_TRANS
        `READ_FROM(5'h13)
        chk(32'hDEAD_1234, data_out, "Data survives 10-cycle rw_ toggle storm");

        // T64: Rapid rw_ toggle while CS=0 — FSM stuck in RESET, write impossible
        `FULL_RESET
        `CS_OFF
        begin : toggle_cs0
            for (int k = 0; k < 8; k++) begin
                @(posedge clk); @(negedge clk);
                rw_ = ~rw_;
            end
        end
        `CS_ON
        rw_ = 1'b1;              // settle into READ
        `CLK_PERIOD_DEF
        `CLK_PERIOD_DEF
        wr_addr = 5'h13;
        `CLK_PERIOD_DEF
        chk(32'h0000_0000, data_out, "rw_ toggle with CS=0: no write, read=0");

        // ══════════════════════════════════════════════════════════
        // GROUP I ─ WRITE ZERO vs UNWRITTEN DISAMBIGUATION (T65-T66)
        // ══════════════════════════════════════════════════════════

        // Writing 0x00000000 to addr 2 (col=2).  Addr 3 (col=3) is never written.
        // col=3 not in check_zero_cols → read of addr 3 must return 0 from MEM_ZERO path.
        // col=2 IS in check_zero_cols → read of addr 2 returns written 0.
        `FULL_RESET
        `CS_ON
        `RESET_WRITE_TRANS
        `WRITE_TO(5'h02, 32'h0000_0000)   // row=0, col=2 — write explicit zero
        `WRITE_READ_TRANS
        `READ_FROM(5'h03)                   // row=0, col=3 — never written
        chk(32'h0000_0000, data_out, "Unwritten col=3: check_zero gate blocks → MEM_ZERO");
        `READ_FROM(5'h02)
        chk(32'h0000_0000, data_out, "Written zero col=2: check_zero passes → reads 0x0");

        // ══════════════════════════════════════════════════════════
        // GROUP J ─ SIMULTANEOUS SIGNAL EDGES (T67-T68)
        // ══════════════════════════════════════════════════════════

        // T67: rst and rw_ change at the same negedge-of-clock moment
        //      Async rst must win — FSM goes to RESET_STATE regardless of rw_
        `FULL_RESET
        `CS_ON
        `RESET_WRITE_TRANS
        `WRITE_TO(5'h14, 32'hBEEF_BEEF)
        // Both signals change at negedge (between posedge transactions)
        @(negedge clk);
        rst = 1'b0;
        rw_ = 1'b0;    // attempt write at same time as reset
        @(posedge clk); @(negedge clk);
        rst = 1'b1;
        `CLK_PERIOD_DEF
        `WRITE_READ_TRANS
        `READ_FROM(5'h14)
        chk(32'h0000_0000, data_out, "Simultaneous rst+rw_ edge: reset wins, read=0");

        // T68: cs and rst both asserted simultaneously
        `FULL_RESET
        `CS_ON
        `RESET_WRITE_TRANS
        `WRITE_TO(5'h16, 32'h1234_ABCD)
        @(negedge clk);
        rst = 1'b0;
        cs  = 1'b0;     // both reset and CS pulled low
        @(posedge clk); @(negedge clk);
        rst = 1'b1;
        cs  = 1'b1;
        `CLK_PERIOD_DEF
        `WRITE_READ_TRANS
        `READ_FROM(5'h16)
        chk(32'h0000_0000, data_out, "Simultaneous rst+cs_low: data_out=0 after");

        // ══════════════════════════════════════════════════════════
        // GROUP K ─ RESET STRESS (T69-T71)
        // ══════════════════════════════════════════════════════════

        // T69: Multiple consecutive resets do not corrupt state machine
        `FULL_RESET
        `CS_ON
        `RESET_WRITE_TRANS
        `WRITE_TO(5'h0A, 32'hDECA_FBAD)
        `WRITE_READ_TRANS
        `READ_FROM(5'h0A)
        chk(32'hDECA_FBAD, data_out, "Pre-multi-reset value readable");
        // Three resets in a row
        `RESET
        `RESET
        `RESET
        `RESET_READ_TRANS
        `READ_FROM(5'h0A)
        chk(32'h0000_0000, data_out, "After 3 consecutive resets: read=0");

        // T70: Reset immediately after reset (rst=0 asserted, released, then 0 again)
        `FULL_RESET
        `CS_ON
        `RESET_WRITE_TRANS
        `WRITE_TO(5'h0B, 32'hABBA_ABBA)
        rst = 1'b0;
        `CLK_PERIOD_DEF
        rst = 1'b1;
        `CLK_PERIOD_DEF
        rst = 1'b0;
        `CLK_PERIOD_DEF
        rst = 1'b1;
        `CLK_PERIOD_DEF
        `WRITE_READ_TRANS
        `READ_FROM(5'h0B)
        chk(32'h0000_0000, data_out, "Double-pulse reset: read=0");

        // T71: Very short rst pulse (1ns — async must still catch it)
        `FULL_RESET
        `CS_ON
        `RESET_WRITE_TRANS
        `WRITE_TO(5'h0C, 32'h1357_2468)
        `WRITE_READ_TRANS
        `READ_FROM(5'h0C)
        chk(32'h1357_2468, data_out, "Short-pulse setup: value before pulse");
        @(negedge clk);
        rst = 1'b0;
        #1;              // 1 ns — shorter than a half-clock
        rst = 1'b1;
        @(posedge clk); @(negedge clk);
        `WRITE_READ_TRANS
        `READ_FROM(5'h0C)
        begin
            test_count++;
            $display("[INFO] T%03d: 1ns rst pulse — data_out=0x%08h", test_count, data_out);
            $display("         If 0x00000000 → async FF caught short pulse");
            $display("         If 0x1357_2468 → pulse too short to propagate (glitch filtered)");
        end

        // ══════════════════════════════════════════════════════════
        // SUMMARY
        // ══════════════════════════════════════════════════════════
        `CLK_PERIOD_DEF
        $display("====================================================");
        $display("  DONE:  %0d tests   %0d PASS   %0d FAIL",
                 test_count, pass_count, fail_count);
        $display("====================================================");
        $finish;
    end

endmodule
