`timescale 1ns/1ps
`include "nar_params.vh"

// ═══════════════════════════════════════════════════════════════════════
//  NEW CS SEMANTICS (design v2)
//
//   cs = 0  →  FSM transitions normally, reads work, writes BLOCKED
//   cs = 1  →  FSM FROZEN (holds current state),
//               writes FIRE  (only when fsm_state == WRITE_STATE),
//               data_out forced to 0
//
//  Typical write flow:
//    1. cs=0, rw_=0, CLK   → navigate FSM to WRITE_STATE
//    2. set wr_addr/data_in, cs=1, CLK → write commits (FSM stays put)
//    3. cs=0                → release
//
//  Typical read flow:
//    1. cs=0, rw_=1, CLK   → navigate FSM to READ_STATE
//    2. set wr_addr, CLK   → data_out valid (cs must stay 0)
// ═══════════════════════════════════════════════════════════════════════

// ── Timing primitive ─────────────────────────────────────────────────
`define CLK_PERIOD_DEF   \
    begin                \
    @(posedge clk);      \
    @(negedge clk);      \
    end

// ── Hardware reset (active-low async, cs state irrelevant during rst) ─
`define RESET       \
    begin           \
    `CLK_PERIOD_DEF \
    rst = 1'b0;     \
    `CLK_PERIOD_DEF \
    rst = 1'b1;     \
    `CLK_PERIOD_DEF \
    end

// ── WRITE_TO(addr, data) ──────────────────────────────────────────────
//   Phase 1 (cs=0, rw_=0, CLK): move FSM toward WRITE_STATE
//   Phase 2 (set addr/data, cs=1, CLK): freeze FSM, fire write
//   Phase 3 (cs=0): release
`define WRITE_TO(addr, data) \
    begin                    \
    cs      = 1'b0;          \
    rw_     = 1'b0;          \
    `CLK_PERIOD_DEF          \
    wr_addr = addr;          \
    data_in = data;          \
    cs      = 1'b1;          \
    `CLK_PERIOD_DEF          \
    cs      = 1'b0;          \
    end

// ── READ_FROM(addr) ───────────────────────────────────────────────────
//   Phase 1 (cs=0, rw_=1, CLK): move FSM toward READ_STATE
//   Phase 2 (set addr, CLK, cs=0): data_out valid after this
`define READ_FROM(addr) \
    begin               \
    cs      = 1'b0;     \
    rw_     = 1'b1;     \
    `CLK_PERIOD_DEF     \
    wr_addr = addr;     \
    `CLK_PERIOD_DEF     \
    end

// ── FULL_RESET ────────────────────────────────────────────────────────
//   Drive all inputs to known state, pulse rst.
//   Leaves: rst=1, rw_=1, cs=0, wr_addr=0, data_in=0, FSM=READ_STATE
`define FULL_RESET    \
    begin             \
    rst     = 1'b1;   \
    rw_     = 1'b1;   \
    cs      = 1'b0;   \
    wr_addr = '0;     \
    data_in = '0;     \
    `RESET            \
    end

// ════════════════════════════════════════════════════════════════════════
module tb_scratchpad_memory_v7;

    localparam DATA_WIDTH  = NAR_NUM_BITS;         // 32
    localparam ROWS        = NAR_MAT_ROWS;         // 5
    localparam COLS        = NAR_MAT_COLS;         // 5
    localparam MEM_ADDRESS = $clog2(ROWS * COLS);  // 5
    localparam DEPTH       = ROWS * COLS;          // 25
    localparam CLK_PERIOD  = 10;

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

    scratchpad_memory #(
        .DATA_WIDTH (DATA_WIDTH),
        .ROWS       (ROWS),
        .COLS       (COLS),
        .MEM_ADDRESS(MEM_ADDRESS)
    ) dut (
        .clk(clk), .rst(rst), .rw_(rw_), .cs(cs),
        .wr_addr(wr_addr), .data_in(data_in), .data_out(data_out)
    );

    initial begin clk = 0; forever #(CLK_PERIOD/2) clk = ~clk; end

    initial begin
        $dumpfile("tb_scratchpad_memory_v7.vcd");
        $dumpvars(0, tb_scratchpad_memory_v7);
    end

    task automatic test_pass(string name);
        pass_count++; test_count++;
        $display("[PASS] T%03d: %s", test_count, name);
    endtask

    task automatic test_fail(string name, string reason);
        fail_count++; test_count++;
        $display("[FAIL] T%03d: %s  |  %s", test_count, name, reason);
    endtask

    task automatic chk(
        logic [DATA_WIDTH-1:0] exp,
        logic [DATA_WIDTH-1:0] got,
        string name
    );
        if (exp !== got)
            test_fail(name, $sformatf("exp=0x%08h  got=0x%08h", exp, got));
        else
            test_pass(name);
    endtask

    // ════════════════════════════════════════════════════════════════════
    initial begin

        rst = 1; rw_ = 1; cs = 0; wr_addr = 0; data_in = 0;
        `RESET

        $display("=======================================================");
        $display("  scratchpad_memory  TB v7  (new CS semantics)");
        $display("  cs=0 → FSM moves / reads work / writes blocked");
        $display("  cs=1 → FSM frozen / write fires (WRITE_STATE) / out=0");
        $display("=======================================================");

        // ═══════════════════════════════════════════════════════════
        // GROUP A — BASIC SANITY (T1–T4)
        // ═══════════════════════════════════════════════════════════

        // T1: Basic write then read
        `FULL_RESET
        `WRITE_TO(5'h0A, 32'hDEAD_BEEF)
        `READ_FROM(5'h0A)
        chk(32'hDEAD_BEEF, data_out, "Basic write/read same addr");

        // T2: Write addr A, read addr B (never written)
        `FULL_RESET
        `WRITE_TO(5'h0A, 32'hFACE_CAFE)
        `READ_FROM(5'h0B)
        chk(32'h0000_0000, data_out, "Read unwritten addr → 0 (check_zero gate)");

        // T3: Read before any write (clear_all=1 locks output to 0)
        `FULL_RESET
        `READ_FROM(5'h00)
        chk(32'h0000_0000, data_out, "Read before write (clear_all=1) → 0");

        // T4: Write then read different addr in same row (different col → gate blocks)
        `FULL_RESET
        `WRITE_TO(5'h00, 32'hAAAA_1111)   // row=0, col=0
        `READ_FROM(5'h04)                   // row=0, col=4 — never written
        chk(32'h0000_0000, data_out, "Same row, different col unwritten → 0");

        // ═══════════════════════════════════════════════════════════
        // GROUP B — CS BEHAVIOR (T5–T12)
        // ═══════════════════════════════════════════════════════════

        // T5: cs=0 always — write block never fires even when in WRITE_STATE
        `FULL_RESET
        cs = 0; rw_ = 0;
        `CLK_PERIOD_DEF   // → WRITE_STATE
        wr_addr = 5'h01;
        data_in = 32'hBAD0_C0DE;
        `CLK_PERIOD_DEF   // WRITE_STATE, cs=0 → write BLOCKED
        `CLK_PERIOD_DEF   // still in WRITE_STATE, still blocked
        `READ_FROM(5'h01)
        chk(32'h0000_0000, data_out, "In WRITE_STATE with cs=0: no write fires");

        // T6: cs=1 entire time → FSM stuck, data_out=0
        `FULL_RESET
        cs = 1'b1;
        repeat (6) @(posedge clk);
        @(negedge clk);
        chk(32'h0000_0000, data_out, "cs=1 entire session: data_out forced 0");
        cs = 1'b0;

        // T7: cs=1 blocks data_out even after a valid write
        `FULL_RESET
        `WRITE_TO(5'h05, 32'h1234_5678)
        // Hold cs=1 (FSM stays in WRITE_STATE, same addr re-written harmlessly, out=0)
        cs = 1'b1;
        `CLK_PERIOD_DEF
        chk(32'h0000_0000, data_out, "cs=1 after write: data_out forced to 0");
        `CLK_PERIOD_DEF
        chk(32'h0000_0000, data_out, "cs=1 after write (2nd cycle): still 0");
        cs = 1'b0;
        // Release and read — data must still be in memory
        `READ_FROM(5'h05)
        chk(32'h1234_5678, data_out, "cs released: data readable after cs=1 hold");

        // T8: cs=1 in READ_STATE → output cleared; cs=0 restores it
        `FULL_RESET
        `WRITE_TO(5'h06, 32'hBEEF_CAFE)
        // Manually go to READ_STATE:
        cs = 0; rw_ = 1;
        `CLK_PERIOD_DEF   // → READ_STATE
        wr_addr = 5'h06;
        `CLK_PERIOD_DEF   // data_out = BEEF_CAFE (cs=0, READ_STATE)
        chk(32'hBEEF_CAFE, data_out, "cs=0 in READ_STATE: data valid");
        cs = 1'b1;
        `CLK_PERIOD_DEF   // FSM frozen in READ_STATE, data_out → 0
        chk(32'h0000_0000, data_out, "cs=1 in READ_STATE: data_out=0");
        cs = 1'b0;
        `CLK_PERIOD_DEF   // back to cs=0, READ_STATE, same addr
        chk(32'hBEEF_CAFE, data_out, "cs released in READ_STATE: data returns");

        // T9: cs=1 in RESET_STATE (not WRITE_STATE) → write block does NOT fire
        `FULL_RESET
        // Assert rst with cs=1 to land in RESET_STATE with cs=1:
        cs  = 1'b1;
        rst = 1'b0;
        `CLK_PERIOD_DEF
        rst = 1'b1;
        // Now: fsm_state=RESET_STATE, cs=1 → FSM frozen in RESET_STATE
        wr_addr = 5'h0C;
        data_in = 32'hBAD0_BAAD;
        `CLK_PERIOD_DEF   // RESET_STATE ≠ WRITE_STATE → write block does NOT fire
        cs = 1'b0;
        `READ_FROM(5'h0C)
        chk(32'h0000_0000, data_out, "cs=1 in RESET_STATE: write blocked (not WRITE_STATE)");

        // T10: cs pulse — exactly one committed write, adjacent addr not touched
        `FULL_RESET
        cs = 0; rw_ = 0;
        `CLK_PERIOD_DEF   // → WRITE_STATE
        wr_addr = 5'h02; data_in = 32'hAAAA_1111;
        `CLK_PERIOD_DEF   // cs=0 → no write
        cs = 1'b1;
        `CLK_PERIOD_DEF   // cs=1 → write fires at 0x02
        cs = 1'b0;
        `READ_FROM(5'h02)
        chk(32'hAAAA_1111, data_out, "cs=1 pulse commits write at addr 0x02");
        `READ_FROM(5'h03)
        chk(32'h0000_0000, data_out, "Adjacent addr 0x03 untouched");

        // T11: Two cs=1 pulses to same addr — second value wins
        `FULL_RESET
        `WRITE_TO(5'h07, 32'h1111_1111)
        `WRITE_TO(5'h07, 32'h2222_2222)
        `READ_FROM(5'h07)
        chk(32'h2222_2222, data_out, "Two writes same addr: second value wins");

        // T12: cs=1 while rst=0 (simultaneously) — reset wins
        `FULL_RESET
        `WRITE_TO(5'h08, 32'hDECA_FBAD)
        rst = 1'b0;
        cs  = 1'b1;    // cs=1 during active reset
        `CLK_PERIOD_DEF
        rst = 1'b1;
        cs  = 1'b0;
        `CLK_PERIOD_DEF
        `READ_FROM(5'h08)
        chk(32'h0000_0000, data_out, "cs=1 during rst=0: reset wins, read=0");

        // ═══════════════════════════════════════════════════════════
        // GROUP C — FSM STATE TRANSITION COVERAGE (T13–T22)
        // ═══════════════════════════════════════════════════════════

        // T13: RESET→WRITE→READ (canonical path)
        `FULL_RESET
        `WRITE_TO(5'h00, 32'h1111_0000)
        `READ_FROM(5'h00)
        chk(32'h1111_0000, data_out, "RESET→WRITE→READ: canonical path");

        // T14: WRITE→READ→WRITE (overwrite same addr)
        `FULL_RESET
        `WRITE_TO(5'h01, 32'h2222_0000)
        `READ_FROM(5'h01)
        chk(32'h2222_0000, data_out, "W→R→W: value before overwrite");
        `WRITE_TO(5'h01, 32'h3333_0000)
        `READ_FROM(5'h01)
        chk(32'h3333_0000, data_out, "W→R→W: overwritten value");

        // T15: Sustained READ (multiple reads without write)
        `FULL_RESET
        `WRITE_TO(5'h02, 32'hAAAA_AAAA)
        `READ_FROM(5'h02)
        chk(32'hAAAA_AAAA, data_out, "Sustained READ: 1st read");
        `READ_FROM(5'h02)
        chk(32'hAAAA_AAAA, data_out, "Sustained READ: 2nd read");
        `READ_FROM(5'h02)
        chk(32'hAAAA_AAAA, data_out, "Sustained READ: 3rd read");

        // T16: READ→WRITE (explicit READ→WRITE transition with rw_ change)
        `FULL_RESET
        `WRITE_TO(5'h03, 32'hBBBB_BBBB)
        `READ_FROM(5'h03)
        chk(32'hBBBB_BBBB, data_out, "Before READ→WRITE transition");
        // Stay in READ one more cycle, then switch to WRITE
        cs = 0; rw_ = 1;
        `CLK_PERIOD_DEF
        `WRITE_TO(5'h03, 32'hCCCC_CCCC)
        `READ_FROM(5'h03)
        chk(32'hCCCC_CCCC, data_out, "After READ→WRITE overwrite");

        // T17: WRITE→RESET→READ — reset clears clear_all, so read must return 0
        `FULL_RESET
        `WRITE_TO(5'h04, 32'hDEAD_C0DE)
        `RESET
        `READ_FROM(5'h04)
        chk(32'h0000_0000, data_out, "W→RST→R: clear_all=1 after reset → 0");

        // T18: RESET→READ directly (no write ever)
        `FULL_RESET
        `READ_FROM(5'h05)
        chk(32'h0000_0000, data_out, "RESET→READ (no write): 0");

        // T19: WRITE→WRITE→WRITE same addr: last wins
        `FULL_RESET
        `WRITE_TO(5'h06, 32'h1001_1001)
        `WRITE_TO(5'h06, 32'h2002_2002)
        `WRITE_TO(5'h06, 32'h3003_3003)
        `READ_FROM(5'h06)
        chk(32'h3003_3003, data_out, "3 consecutive writes same addr: last value");

        // T20: Write A, reset, write B same addr, read → B (not A)
        `FULL_RESET
        `WRITE_TO(5'h07, 32'hAAAA_0000)
        `RESET
        `WRITE_TO(5'h07, 32'hBBBB_0000)
        `READ_FROM(5'h07)
        chk(32'hBBBB_0000, data_out, "Write, reset, re-write: second value");

        // T21: Sustained WRITE_STATE (cs=0, multiple hold cycles) then commit
        `FULL_RESET
        `WRITE_TO(5'h08, 32'hCCCC_CCCC)
        cs = 0; rw_ = 0;
        repeat (4) `CLK_PERIOD_DEF   // hold in WRITE_STATE, no commit (cs=0)
        wr_addr = 5'h08;
        data_in = 32'hDDDD_DDDD;
        cs = 1;
        `CLK_PERIOD_DEF
        cs = 0;
        `READ_FROM(5'h08)
        chk(32'hDDDD_DDDD, data_out, "Hold in WRITE_STATE then commit: new value");

        // T22: Change read address within sustained READ_STATE
        `FULL_RESET
        `WRITE_TO(5'h09, 32'hEEEE_EEEE)
        `WRITE_TO(5'h0A, 32'hFFFF_FFFF)
        `READ_FROM(5'h09)
        chk(32'hEEEE_EEEE, data_out, "Sustained READ: addr 0x09");
        // Stay in READ_STATE, just change wr_addr — no state transition needed
        cs = 0; rw_ = 1;
        wr_addr = 5'h0A;
        `CLK_PERIOD_DEF
        chk(32'hFFFF_FFFF, data_out, "Sustained READ: addr 0x0A (no FSM transition)");

        // ═══════════════════════════════════════════════════════════
        // GROUP D — BURST WRITE (cs=1 held, addr/data change each CLK) (T23–T25)
        // ═══════════════════════════════════════════════════════════
        //
        // While cs=1 AND fsm_state=WRITE_STATE, every posedge fires a write.
        // Change wr_addr+data_in each clock for a burst load.
        //
        `FULL_RESET
        cs = 0; rw_ = 0;
        `CLK_PERIOD_DEF  // → WRITE_STATE
        // Burst: cs=1 held, 3 successive writes
        cs = 1'b1;
        wr_addr = 5'h0B; data_in = 32'hBBBB_000B; `CLK_PERIOD_DEF
        wr_addr = 5'h0C; data_in = 32'hBBBB_000C; `CLK_PERIOD_DEF
        wr_addr = 5'h0D; data_in = 32'hBBBB_000D; `CLK_PERIOD_DEF
        cs = 1'b0;
        `READ_FROM(5'h0B) chk(32'hBBBB_000B, data_out, "Burst: addr 0x0B");
        `READ_FROM(5'h0C) chk(32'hBBBB_000C, data_out, "Burst: addr 0x0C");
        `READ_FROM(5'h0D) chk(32'hBBBB_000D, data_out, "Burst: addr 0x0D");

        // T26: Burst write with rw_ toggling (rw_ doesn't matter when cs=1, FSM frozen)
        `FULL_RESET
        cs = 0; rw_ = 0;
        `CLK_PERIOD_DEF  // → WRITE_STATE
        cs = 1'b1;
        wr_addr = 5'h0E; data_in = 32'hEEEE_000E; rw_ = 1'b0; `CLK_PERIOD_DEF   // write fires
        wr_addr = 5'h0F; data_in = 32'hEEEE_000F; rw_ = 1'b1; `CLK_PERIOD_DEF   // rw_=1 but FSM frozen → still WRITE_STATE, write fires
        wr_addr = 5'h10; data_in = 32'hEEEE_0010; rw_ = 1'b0; `CLK_PERIOD_DEF   // write fires
        cs = 1'b0;
        `READ_FROM(5'h0E) chk(32'hEEEE_000E, data_out, "Burst+rw_ toggle: addr 0x0E");
        `READ_FROM(5'h0F) chk(32'hEEEE_000F, data_out, "Burst+rw_ toggle: addr 0x0F (rw_=1 during cs=1)");
        `READ_FROM(5'h10) chk(32'hEEEE_0010, data_out, "Burst+rw_ toggle: addr 0x10");

        // ═══════════════════════════════════════════════════════════
        // GROUP E — ADDRESS BOUNDARY (T27–T30)
        // ═══════════════════════════════════════════════════════════

        // T27: Minimum valid address (0)
        `FULL_RESET
        `WRITE_TO(5'h00, 32'hABCD_0000)
        `READ_FROM(5'h00)
        chk(32'hABCD_0000, data_out, "Addr 0 (min): write/read");

        // T28: Maximum valid address (24 = 0x18)
        `FULL_RESET
        `WRITE_TO(5'h18, 32'h0000_ABCD)
        `READ_FROM(5'h18)
        chk(32'h0000_ABCD, data_out, "Addr 24/0x18 (max valid): write/read");

        // T29: OOB — addr 25 (row=5, outside [0..4])
        `FULL_RESET
        `WRITE_TO(5'h19, 32'hDEAD_DEAD)
        `READ_FROM(5'h19)
        begin
            test_count++;
            $display("[INFO] T%03d: OOB addr 25 (0x19): data_out=0x%08h [expect X or 0]",
                     test_count, data_out);
            if (^data_out === 1'bx)
                $display("         → X bits present (uninitialized OOB access, expected)");
        end

        // T30: OOB — addr 31 (row=6, maximum 5-bit OOB)
        `FULL_RESET
        `WRITE_TO(5'h1F, 32'hBEEF_BEEF)
        `READ_FROM(5'h1F)
        begin
            test_count++;
            $display("[INFO] T%03d: OOB addr 31 (0x1F): data_out=0x%08h [expect X or 0]",
                     test_count, data_out);
            if (^data_out === 1'bx)
                $display("         → X bits present");
        end

        // ═══════════════════════════════════════════════════════════
        // GROUP F — DATA PATTERNS (T31–T34)
        // ═══════════════════════════════════════════════════════════

        `FULL_RESET
        `WRITE_TO(5'h13, 32'h0000_0000)
        `READ_FROM(5'h13)
        chk(32'h0000_0000, data_out, "Pattern 0x00000000");

        `FULL_RESET
        `WRITE_TO(5'h14, 32'hFFFF_FFFF)
        `READ_FROM(5'h14)
        chk(32'hFFFF_FFFF, data_out, "Pattern 0xFFFFFFFF");

        `FULL_RESET
        `WRITE_TO(5'h15, 32'hAAAA_AAAA)
        `READ_FROM(5'h15)
        chk(32'hAAAA_AAAA, data_out, "Pattern 0xAAAAAAAA");

        `FULL_RESET
        `WRITE_TO(5'h16, 32'h5555_5555)
        `READ_FROM(5'h16)
        chk(32'h5555_5555, data_out, "Pattern 0x55555555");

        // ═══════════════════════════════════════════════════════════
        // GROUP G — check_zero APPROXIMATION BUG (T35)
        // ═══════════════════════════════════════════════════════════
        //
        // Write (r=0,c=0)=addr 0 and (r=1,c=1)=addr 6.
        // This sets check_zero_rows[0,1]=1 and check_zero_cols[0,1]=1.
        // Reading addr 1 (r=0, c=1): BOTH bits set → gate passes,
        // but memory[0][1] was NEVER written → returns X or stale.
        //
        `FULL_RESET
        `WRITE_TO(5'h00, 32'hDEAD_0000)   // (r=0, c=0)
        `WRITE_TO(5'h06, 32'h0000_BEEF)   // (r=1, c=1)
        `READ_FROM(5'h01)                   // (r=0, c=1) — NEVER written
        begin
            test_count++;
            $display("[BUG]  T%03d: check_zero approx — addr 1 (r=0,c=1) never written",
                     test_count);
            $display("         data_out = 0x%08h", data_out);
            if (^data_out === 1'bx) begin
                fail_count++;
                $display("         FAIL → X leaked through check_zero gate");
            end else if (data_out !== 32'h0) begin
                fail_count++;
                $display("         FAIL → non-zero stale value from unwritten cell");
            end else begin
                pass_count++;
                $display("         PASS → coincidentally 0 (uninit default)");
            end
        end

        // ═══════════════════════════════════════════════════════════
        // GROUP H — FULL 25-ADDRESS BURST SWEEP (T36–T60)
        // ═══════════════════════════════════════════════════════════

        `FULL_RESET

        // Navigate to WRITE_STATE once (cs=0):
        cs = 0; rw_ = 0;
        `CLK_PERIOD_DEF  // → WRITE_STATE

        // Burst write all 25 locations — cs=1 held, addr+data change each posedge
        cs = 1'b1;
        for (int i = 0; i < DEPTH; i++) begin
            wr_addr = i[MEM_ADDRESS-1:0];
            data_in = 32'hC0DE_0000 | i[DATA_WIDTH-1:0];
            @(posedge clk); @(negedge clk);
        end
        cs = 1'b0;

        // Transition to READ_STATE (cs=0, rw_=1, 1 clock):
        cs = 0; rw_ = 1;
        @(posedge clk); @(negedge clk);  // → READ_STATE

        // Read all 25 locations
        for (int i = 0; i < DEPTH; i++) begin
            wr_addr = i[MEM_ADDRESS-1:0];
            @(posedge clk); @(negedge clk);
            chk(32'hC0DE_0000 | i[DATA_WIDTH-1:0], data_out,
                $sformatf("Full burst sweep: addr %0d", i));
        end

        // ═══════════════════════════════════════════════════════════
        // GROUP I — ASYNC RESET (T61–T63)
        // ═══════════════════════════════════════════════════════════

        // T61: data_out → 0 immediately on async rst assertion (not clock-aligned)
        `FULL_RESET
        `WRITE_TO(5'h17, 32'hFACE_CAFE)
        `READ_FROM(5'h17)
        chk(32'hFACE_CAFE, data_out, "Async rst setup: value before rst");
        @(negedge clk);
        #(CLK_PERIOD * 0.3);   // mid-low-phase, not at any edge
        rst = 1'b0;
        #1;
        chk(32'h0000_0000, data_out, "Async rst: data_out=0 within 1ns of rst assertion");

        // T62: After rst release (cs=0), read returns 0 (clear_all=1)
        rst = 1'b1;
        `CLK_PERIOD_DEF
        `READ_FROM(5'h17)
        chk(32'h0000_0000, data_out, "Post-rst read: clear_all=1 → 0");

        // T63: Async rst fires mid-write (cs=1 raised, rst fires before posedge)
        `FULL_RESET
        cs = 0; rw_ = 0;
        `CLK_PERIOD_DEF   // → WRITE_STATE
        wr_addr = 5'h18;
        data_in = 32'hBEEF_BABE;
        cs = 1'b1;
        #(CLK_PERIOD * 0.3);   // rst fires before the write posedge
        rst = 1'b0;
        #(CLK_PERIOD * 0.3);
        chk(32'h0000_0000, data_out, "Async rst mid-write: data_out=0 immediately");
        rst = 1'b1;
        cs  = 1'b0;
        `CLK_PERIOD_DEF
        `READ_FROM(5'h18)
        chk(32'h0000_0000, data_out, "Post mid-write rst: write not committed");

        // ═══════════════════════════════════════════════════════════
        // GROUP J — SIMULTANEOUS EDGE CONDITIONS (T64–T66)
        // ═══════════════════════════════════════════════════════════

        // T64: rst and cs both asserted at negedge — reset must win
        `FULL_RESET
        `WRITE_TO(5'h0D, 32'h1357_2468)
        @(negedge clk);
        rst = 1'b0;
        cs  = 1'b1;
        @(posedge clk); @(negedge clk);
        rst = 1'b1;
        cs  = 1'b0;
        `CLK_PERIOD_DEF
        `READ_FROM(5'h0D)
        chk(32'h0000_0000, data_out, "Simultaneous rst+cs=1: reset wins, read=0");

        // T65: rst and rw_ change simultaneously (rst wins over FSM navigation)
        `FULL_RESET
        `WRITE_TO(5'h0E, 32'hABBA_ABBA)
        @(negedge clk);
        rst = 1'b0;
        rw_ = 1'b0;   // would go to WRITE_STATE, but rst is low
        @(posedge clk); @(negedge clk);
        rst = 1'b1;
        `CLK_PERIOD_DEF
        `READ_FROM(5'h0E)
        chk(32'h0000_0000, data_out, "Simultaneous rst+rw_ edge: reset wins, read=0");

        // T66: cs=1 and rst=1 simultaneously after rst release
        //      (cs=1 should freeze FSM, NOT let it transition on rst release)
        `FULL_RESET
        rst = 1'b0;
        cs  = 1'b1;   // both cs=1 and rst=0 together
        `CLK_PERIOD_DEF
        rst = 1'b1;   // release rst while cs=1 → FSM held in RESET_STATE
        wr_addr = 5'h0F;
        data_in = 32'hDEAD_BAAD;
        `CLK_PERIOD_DEF   // cs=1, RESET_STATE → write block blocked (not WRITE_STATE)
        cs = 1'b0;
        `READ_FROM(5'h0F)
        chk(32'h0000_0000, data_out, "cs=1 on rst release keeps RESET_STATE: no write");

        // ═══════════════════════════════════════════════════════════
        // GROUP K — RESET STRESS (T67–T69)
        // ═══════════════════════════════════════════════════════════

        // T67: Three consecutive resets
        `FULL_RESET
        `WRITE_TO(5'h11, 32'hDECA_FBAD)
        `RESET
        `RESET
        `RESET
        `READ_FROM(5'h11)
        chk(32'h0000_0000, data_out, "3 consecutive resets → read=0");

        // T68: Write, double-pulse rst, write new value, read → new value
        `FULL_RESET
        `WRITE_TO(5'h12, 32'hAAAA_BBBB)
        rst = 0; `CLK_PERIOD_DEF
        rst = 1; `CLK_PERIOD_DEF
        rst = 0; `CLK_PERIOD_DEF
        rst = 1; `CLK_PERIOD_DEF
        `WRITE_TO(5'h12, 32'hCCCC_DDDD)
        `READ_FROM(5'h12)
        chk(32'hCCCC_DDDD, data_out, "Double-pulse rst then re-write: second value");

        // T69: 1 ns short rst pulse (sub-half-clock — tech-dependent)
        `FULL_RESET
        `WRITE_TO(5'h13, 32'h1357_2468)
        `READ_FROM(5'h13)
        chk(32'h1357_2468, data_out, "Short-pulse rst setup: pre-pulse read");
        @(negedge clk);
        rst = 1'b0;
        #1;            // 1 ns — shorter than half-clock (5 ns)
        rst = 1'b1;
        @(posedge clk); @(negedge clk);
        `READ_FROM(5'h13)
        begin
            test_count++;
            $display("[INFO] T%03d: 1ns rst pulse — data_out=0x%08h", test_count, data_out);
            $display("         0x00000000 → async FF caught glitch");
            $display("         0x13572468 → pulse too short (glitch filtered by sim)");
        end

        // ═══════════════════════════════════════════════════════════
        // GROUP L — WRITE ZERO vs UNWRITTEN DISAMBIGUATION (T70–T71)
        // ═══════════════════════════════════════════════════════════

        // Write 0 to addr 2 (r=0,c=2). Addr 3 (r=0,c=3) never written.
        // check_zero_cols[2]=1, check_zero_cols[3]=0 → gate blocks addr 3.
        `FULL_RESET
        `WRITE_TO(5'h02, 32'h0000_0000)
        `READ_FROM(5'h03)   // (r=0, c=3) — never written
        chk(32'h0000_0000, data_out, "Unwritten col=3: check_zero blocks → MEM_ZERO");
        `READ_FROM(5'h02)   // (r=0, c=2) — written zero
        chk(32'h0000_0000, data_out, "Written zero col=2: reads back 0x0");

        // ═══════════════════════════════════════════════════════════
        // GROUP M — rw_ RAPID TOGGLING (T72–T73)
        // ═══════════════════════════════════════════════════════════

        // T72: rw_ toggled 10 times with cs=0 — no writes fire, data survives
        `FULL_RESET
        `WRITE_TO(5'h14, 32'hDEAD_1234)
        cs = 0;
        repeat (10) begin
            `CLK_PERIOD_DEF
            rw_ = ~rw_;
        end
        `READ_FROM(5'h14)
        chk(32'hDEAD_1234, data_out, "Data survives 10-cycle rw_ toggle (cs=0 → no writes)");

        // T73: rw_ toggle while cs=1 (burst mode) — FSM ignores rw_, writes every clock
        `FULL_RESET
        cs = 0; rw_ = 0;
        `CLK_PERIOD_DEF  // → WRITE_STATE
        cs = 1'b1;
        wr_addr = 5'h15; data_in = 32'h1111_AAAA; rw_ = 1'b0; `CLK_PERIOD_DEF   // write
        wr_addr = 5'h16; data_in = 32'h2222_BBBB; rw_ = 1'b1; `CLK_PERIOD_DEF   // rw_=1 but cs=1 → FSM frozen, write fires
        wr_addr = 5'h17; data_in = 32'h3333_CCCC; rw_ = 1'b0; `CLK_PERIOD_DEF   // write
        cs = 1'b0;
        `READ_FROM(5'h15) chk(32'h1111_AAAA, data_out, "rw_=0 during cs=1: addr 0x15 written");
        `READ_FROM(5'h16) chk(32'h2222_BBBB, data_out, "rw_=1 during cs=1: FSM frozen, addr 0x16 still written");
        `READ_FROM(5'h17) chk(32'h3333_CCCC, data_out, "rw_=0 during cs=1: addr 0x17 written");

        // ═══════════════════════════════════════════════════════════
        // SUMMARY
        // ═══════════════════════════════════════════════════════════
        `CLK_PERIOD_DEF
        $display("=======================================================");
        $display("  RESULTS: %0d tests  |  %0d PASS  |  %0d FAIL",
                 test_count, pass_count, fail_count);
        $display("=======================================================");
        $finish;
    end

endmodule
