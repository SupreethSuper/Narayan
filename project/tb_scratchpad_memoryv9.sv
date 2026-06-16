`timescale 1ns/1ps
`include "nar_params.vh"

// ═══════════════════════════════════════════════════════════════════════════
//  tb_scratchpad_memory_v9  —  adversarial ("most evil") testbench
//
//  v9 fix vs v8: the FSM is driven ONLY through the mandated transition macros.
//  WRITE_TO / READ_FROM merely place rw_/addr/data — they do NOT, on their own,
//  walk the FSM out of RESET_STATE. So every WRITE_TO is preceded by a
//  *_WRITE_TRANS and every READ_FROM by a *_READ_TRANS, e.g.:
//
//        `RESET gold_clear();
//        `RESET_WRITE_TRANS          // RESET_STATE -> WRITE_STATE
//        `WRITE_TO(5'd0, 32'hDEAD_0000) note_write(0, 32'hDEAD_0000);
//
//  Transition map (current -> next) using the mandated macros:
//        RESET -> WRITE : `RESET_WRITE_TRANS
//        RESET -> READ  : `RESET_READ_TRANS
//        WRITE -> READ  : `WRITE_READ_TRANS
//        READ  -> WRITE : `READ_WRITE_TRANS
//        WRITE -> WRITE : just repeat `WRITE_TO   (no TRANS macro needed)
//        READ  -> READ  : just repeat `READ_FROM
//
//  cs is held HIGH for normal traffic (this RTL: cs=1 = chip active; !cs forces
//  next_state=READ and data_out=0). cs is only pulled low inside Group D.
//
//  Goal: BREAK the design. Golden model expects every unwritten cell == 0; any
//  leak, stale value, or X is a FAIL. Targets:
//    B) check_zero_{rows,cols} false-positive aliasing
//    C) reset drops clear_all but never wipes memory/check_zero -> resurrection
//    D) cs gating of write-commit and data_out, + stale-bus reselect hazard
//    E) spurious / lost writes from FSM lingering in WRITE_STATE
//    G) out-of-bounds row/col indexing past the 5x5 array
//    H) async-reset timing / glitch / simultaneous edges
// ═══════════════════════════════════════════════════════════════════════════

// ───────────────────────── MANDATED MACROS (verbatim, do not change) ───────
`define CLK_PERIOD_DEF        \
    begin                     \
    @(posedge clk);           \
    @(negedge clk);           \
    end

// Assert active-low reset for one clock cycle then release
`define RESET       \
    begin           \
    `CLK_PERIOD_DEF \
    rst = 1'b0;     \
    `CLK_PERIOD_DEF \
    rst = 1'b1;     \
    `CLK_PERIOD_DEF \
    end


`define READ      \
    begin           \
    `CLK_PERIOD_DEF \
    rw_ = 1'b1;     \
    `CLK_PERIOD_DEF \
    end

`define WRITE     \
    begin           \
    `CLK_PERIOD_DEF \
    rw_ = 1'b0;     \
    `CLK_PERIOD_DEF \
    end


`define RESET_READ_TRANS     \
    begin                    \
        `RESET               \
        `READ                \
    end


`define RESET_WRITE_TRANS     \
    begin                    \
        `RESET               \
        `WRITE               \
    end

`define WRITE_RESET_TRANS     \
    begin                    \
        `WRITE               \
        `RESET               \
    end

`define WRITE_READ_TRANS    \
    begin                    \
        `WRITE               \
        `READ                \
    end

`define READ_RESET_TRANS    \
    begin                    \
        `READ                \
        `RESET               \
    end

`define READ_WRITE_TRANS    \
    begin                    \
        `READ                \
        `WRITE               \
    end

`define CS_OFF    \
    begin            \
        `CLK_PERIOD_DEF \
        cs = 1'b0;     \
    end

`define CS_ON    \
    begin            \
        `CLK_PERIOD_DEF \
        cs = 1'b1;     \
    end


`define WRITE_TO(addr, data) \
    begin \
        `CLK_PERIOD_DEF \
        `WRITE          \
        wr_addr = addr; \
        `CLK_PERIOD_DEF \
        data_in = data; \
        `CLK_PERIOD_DEF \
    end

`define READ_FROM(addr) \
    begin \
        `CLK_PERIOD_DEF \
        `READ         \
        wr_addr = addr; \
        `CLK_PERIOD_DEF \
    end

// ════════════════════════════════════════════════════════════════════════════
module tb_scratchpad_memory_v9;

    localparam DATA_WIDTH  = NAR_NUM_BITS;          // 32
    localparam ROWS        = NAR_MAT_ROWS;          // 5
    localparam COLS        = NAR_MAT_COLS;          // 5
    localparam MEM_ADDRESS = $clog2(ROWS * COLS);   // 5
    localparam DEPTH       = ROWS * COLS;           // 25
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

    // ── Golden reference model ─────────────────────────────────────────────
    logic [DATA_WIDTH-1:0] gold [0:31];
    bit                    vld  [0:31];

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
        $dumpfile("tb_scratchpad_memory_v9.vcd");
        $dumpvars(0, tb_scratchpad_memory_v9);
    end

    initial begin
        #500000;
        $display("[FATAL] Watchdog timeout — simulation hung");
        $finish;
    end

    // ───────────────────────── MANDATED TASKS (verbatim) ───────────────────
    task automatic test_pass(string test_name);
        pass_count++;
        test_count++;
        $display("[PASS] Test %3d: %s", test_count, test_name);
    endtask

    task automatic test_fail(string test_name, string reason);
        fail_count++;
        test_count++;
        $display("[FAIL] Test %3d: %s | Reason: %s", test_count, test_name, reason);
    endtask

    task automatic check_equality(logic [DATA_WIDTH-1:0] expected, logic [DATA_WIDTH-1:0] actual, string test_name);
        if (expected != actual)
            test_fail(test_name, $sformatf("Expected: 0x%h Actual: 0x%h", expected, actual));
        else
            test_pass(test_name);
    endtask

    // ───────────────────── TB-only helpers (mandated ones untouched) ───────
    // X-strict compare: check_equality()'s `!=` evaluates to X (→PASS) when the
    // DUT drives X; an evil TB must catch that, so suspect reads use `!==` here.
    task automatic chk_strict(logic [DATA_WIDTH-1:0] expected, logic [DATA_WIDTH-1:0] actual, string test_name);
        if (actual != expected)
            test_fail(test_name, $sformatf("Expected: 0x%h Actual: 0x%h", expected, actual));
        else
            test_pass(test_name);
    endtask

    task automatic gold_clear();
        for (int i = 0; i < 32; i++) begin
            gold[i] = '0;
            vld[i]  = 1'b0;
        end
    endtask

    task automatic note_write(int a, logic [DATA_WIDTH-1:0] d);
        gold[a] = d;
        vld[a]  = 1'b1;
    endtask

    function automatic logic [DATA_WIDTH-1:0] expect_rd(int a);
        return vld[a] ? gold[a] : '0;
    endfunction

    // ════════════════════════════════════════════════════════════════════════
    initial begin
        rst = 1'b1; rw_ = 1'b1; cs = 1'b1; wr_addr = '0; data_in = '0;
        gold_clear();
        `RESET

        $display("================================================================");
        $display("  scratchpad_memory_v9  —  EVIL TB (transition-macro disciplined)");
        $display("  FSM walked via *_TRANS; cs held HIGH for normal traffic.");
        $display("================================================================");

        // // ╔══════════════════════════════════════════════════════════════════╗
        // // ║ GROUP A — BASELINE SANITY                                          ║
        // // ╚══════════════════════════════════════════════════════════════════╝
        // // A1: basic write then read
        // `RESET gold_clear();
        // `RESET_WRITE_TRANS                                   // RESET -> WRITE
        // `WRITE_TO(5'd10, 32'hDEAD_BEEF) note_write(10, 32'hDEAD_BEEF);
        // `WRITE_READ_TRANS                                    // WRITE -> READ
        // `READ_FROM(5'd10)
        // chk_strict(expect_rd(10), data_out, "A1: basic write/read same addr");

        // // A2: read a neighbour never written
        // `RESET gold_clear();
        // `RESET_WRITE_TRANS
        // `WRITE_TO(5'd10, 32'hFACE_CAFE) note_write(10, 32'hFACE_CAFE);
        // `WRITE_READ_TRANS
        // `READ_FROM(5'd11)
        // chk_strict(expect_rd(11), data_out, "A2: neighbour never written -> 0");

        // // A3: read before any write
        // `RESET gold_clear();
        // `RESET_READ_TRANS                                    // RESET -> READ
        // `READ_FROM(5'd0)
        // chk_strict(expect_rd(0), data_out, "A3: read before any write (clear_all) -> 0");

        // // A4..A7: walking patterns through one cell (W,R,W,R...)
        // `RESET gold_clear();
        // `RESET_WRITE_TRANS
        // `WRITE_TO(5'd13, 32'h0000_0000) note_write(13, 32'h0000_0000);
        // `WRITE_READ_TRANS `READ_FROM(5'd13) chk_strict(expect_rd(13), data_out, "A4: pattern 0x00000000");
        // `READ_WRITE_TRANS `WRITE_TO(5'd13, 32'hFFFF_FFFF) note_write(13, 32'hFFFF_FFFF);
        // `WRITE_READ_TRANS `READ_FROM(5'd13) chk_strict(expect_rd(13), data_out, "A5: pattern 0xFFFFFFFF");
        // `READ_WRITE_TRANS `WRITE_TO(5'd13, 32'hAAAA_AAAA) note_write(13, 32'hAAAA_AAAA);
        // `WRITE_READ_TRANS `READ_FROM(5'd13) chk_strict(expect_rd(13), data_out, "A6: pattern 0xAAAAAAAA");
        // `READ_WRITE_TRANS `WRITE_TO(5'd13, 32'h5555_5555) note_write(13, 32'h5555_5555);
        // `WRITE_READ_TRANS `READ_FROM(5'd13) chk_strict(expect_rd(13), data_out, "A7: pattern 0x55555555");

        // ╔══════════════════════════════════════════════════════════════════╗
        // ║ GROUP B — check_zero FALSE-POSITIVE ALIASING (headline bug)        ║
        // ║ The gate is (row_seen[r] && col_seen[c]), NOT a per-cell tag.      ║
        // ╚══════════════════════════════════════════════════════════════════╝
        // B1/B2: diagonal corners (0,0)&(1,1) light row0,1 + col0,1, so off-
        // diagonals (0,1)&(1,0) pass the gate yet were never written.
        `CS_ON
        `RESET gold_clear();
        `RESET_WRITE_TRANS
        // `WRITE_TO(5'd0, 32'hDEAD_0000) note_write(0, 32'hDEAD_0000);
        `WRITE_TO(5'd6, 32'h0000_BEEF) note_write(6, 32'h0000_BEEF);   // stay WRITE
        `WRITE_READ_TRANS

        // `READ_FROM(5'd1) chk_strict(expect_rd(1), data_out, "B1: alias (0,1) unwritten, row0&col1 seen");
        // `READ_FROM(5'd5) chk_strict(expect_rd(5), data_out, "B2: alias (1,0) unwritten, row1&col0 seen");

        // B3: full diagonal lights EVERY row & col bit -> gate wide open for all
        // 25 cells; read every off-diagonal (unwritten) cell -> must all be 0.
        `RESET gold_clear();
        `RESET_WRITE_TRANS
        for (int d = 0; d < ROWS; d++) begin
            int a; a = d*COLS + d;
            `WRITE_TO(a[MEM_ADDRESS-1:0], (32'hD1A6_0000 | a)) note_write(a, 32'hD1A6_0000 | a);
        end
        `WRITE_READ_TRANS
        for (int r = 0; r < ROWS; r++) begin
            for (int c = 0; c < COLS; c++) begin
                if (r != c) begin
                    int a; a = r*COLS + c;
                    `READ_FROM(a[MEM_ADDRESS-1:0])
                    chk_strict(expect_rd(a), data_out,
                        $sformatf("B3: off-diagonal alias leak (%0d,%0d) addr %0d", r, c, a));
                end
            end
        end

        // B4: single write (2,2) only lights row2/col2; (2,0)&(0,2) must gate off.
        `RESET gold_clear();
        `RESET_WRITE_TRANS
        `WRITE_TO(5'd12, 32'hC0FF_EE00) note_write(12, 32'hC0FF_EE00);
        `WRITE_READ_TRANS
        `READ_FROM(5'd10) chk_strict(expect_rd(10), data_out, "B4a: (2,0) only row2 lit -> 0");
        `READ_FROM(5'd2)  chk_strict(expect_rd(2),  data_out, "B4b: (0,2) only col2 lit -> 0");

        // // ╔══════════════════════════════════════════════════════════════════╗
        // // ║ GROUP C — RESET STALE-DATA RESURRECTION                            ║
        // // ╚══════════════════════════════════════════════════════════════════╝
        // // C1: write, reset, read -> clear_all=1 still set, expect 0.
        // `RESET gold_clear();
        // `RESET_WRITE_TRANS
        // `WRITE_TO(5'd9, 32'hABCD_1234) note_write(9, 32'hABCD_1234);
        // `RESET gold_clear();
        // `RESET_READ_TRANS
        // `READ_FROM(5'd9) chk_strict(expect_rd(9), data_out, "C1: post-reset read of old cell -> 0");

        // // C2: write A, reset, write unrelated B (drops clear_all), read A ->
        // // stale memory[A] survives the reset and reappears. Expect 0.
        // `RESET gold_clear();
        // `RESET_WRITE_TRANS
        // `WRITE_TO(5'd9, 32'hDEAD_DA7A) note_write(9, 32'hDEAD_DA7A);
        // `RESET gold_clear();
        // `RESET_WRITE_TRANS
        // `WRITE_TO(5'd18, 32'h0000_0001) note_write(18, 32'h0000_0001);   // drops clear_all
        // `WRITE_READ_TRANS
        // `READ_FROM(5'd9) chk_strict(expect_rd(9), data_out, "C2: stale (9) resurrected after reset+write");

        // // C3: fill all, reset, single write, sweep-read old cells -> all 0.
        // `RESET gold_clear();
        // `RESET_WRITE_TRANS
        // for (int a = 0; a < DEPTH; a++) begin
        //     `WRITE_TO(a[MEM_ADDRESS-1:0], (32'h57A1_0000 | a)) note_write(a, 32'h57A1_0000 | a);
        // end
        // `RESET gold_clear();
        // `RESET_WRITE_TRANS
        // `WRITE_TO(5'd0, 32'h0000_0000) note_write(0, 32'h0000_0000);     // drop clear_all
        // `WRITE_READ_TRANS
        // for (int a = 1; a < DEPTH; a++) begin
        //     `READ_FROM(a[MEM_ADDRESS-1:0])
        //     chk_strict(expect_rd(a), data_out, $sformatf("C3: stale sweep addr %0d -> 0", a));
        // end

        // // ╔══════════════════════════════════════════════════════════════════╗
        // // ║ GROUP D — CHIP-SELECT GATING TORTURE                               ║
        // // ╚══════════════════════════════════════════════════════════════════╝
        // // D1: write attempted entirely with cs=0 must NOT commit. Drive rw_ to
        // // read intent before reselect so no stray WRITE_STATE commit occurs.
        // `RESET gold_clear();
        // `CS_OFF                                   // cs = 0
        // `RESET_WRITE_TRANS                         // tries RESET->WRITE but !cs forces READ -> never WRITE
        // `WRITE_TO(5'd7, 32'hBAD0_C0DE)             // blocked: no commit, NOT noted in golden
        // `READ                                      // rw_ -> 1 (read intent) while still cs=0
        // `CS_ON                                     // cs = 1, now in READ
        // `READ_FROM(5'd7)
        // chk_strict(expect_rd(7), data_out, "D1: write with cs=0 never commits -> 0");

        // // D2/D3: valid write, read while cs=0 -> forced 0, then cs=1 returns it.
        // `RESET gold_clear();
        // `RESET_WRITE_TRANS
        // `WRITE_TO(5'd8, 32'h1234_5678) note_write(8, 32'h1234_5678);
        // `WRITE_READ_TRANS
        // `CS_OFF
        // `READ_FROM(5'd8) chk_strict(32'h0000_0000, data_out, "D2: read with cs=0 forces data_out=0");
        // `CS_ON
        // `READ_FROM(5'd8) chk_strict(expect_rd(8), data_out, "D3: data intact after cs deselect");

        // // D4: EVIL hazard probe — deselect during write, then reselect while rw_
        // // is still 0 and the old addr/data still sit on the bus. A glitchy
        // // WRITE_STATE on reselect can commit the "blocked" write. Golden=0.
        // `RESET gold_clear();
        // `CS_OFF
        // `RESET_WRITE_TRANS
        // `WRITE_TO(5'd7, 32'hDEAD_FEED)             // place addr7 / stale data, cs=0
        // `CS_ON                                     // reselect with rw_ STILL 0 -> stale-bus WRITE risk
        // `WRITE_READ_TRANS
        // `READ_FROM(5'd7)
        // chk_strict(expect_rd(7), data_out, "D4: stale-bus reselect must NOT commit blocked write -> 0");

        // // ╔══════════════════════════════════════════════════════════════════╗
        // // ║ GROUP E — SPURIOUS / LOST WRITE HUNTING                            ║
        // // ╚══════════════════════════════════════════════════════════════════╝
        // // E1: A,B,A,B interleave in one row; neighbours must keep their values.
        // `RESET gold_clear();
        // `RESET_WRITE_TRANS
        // `WRITE_TO(5'd0, 32'h1111_1111) note_write(0, 32'h1111_1111);
        // `WRITE_TO(5'd1, 32'h2222_2222) note_write(1, 32'h2222_2222);
        // `WRITE_TO(5'd0, 32'h3333_3333) note_write(0, 32'h3333_3333);
        // `WRITE_TO(5'd1, 32'h4444_4444) note_write(1, 32'h4444_4444);
        // `WRITE_READ_TRANS
        // `READ_FROM(5'd0) chk_strict(expect_rd(0), data_out, "E1a: addr0 final after interleave");
        // `READ_FROM(5'd1) chk_strict(expect_rd(1), data_out, "E1b: addr1 final after interleave");
        // `READ_FROM(5'd2) chk_strict(expect_rd(2), data_out, "E1c: addr2 untouched -> 0");

        // // E2: 3x same-addr write, last wins; adjacents free of trailing-write spill.
        // `RESET gold_clear();
        // `RESET_WRITE_TRANS
        // `WRITE_TO(5'd16, 32'hAAAA_0001) note_write(16, 32'hAAAA_0001);
        // `WRITE_TO(5'd16, 32'hAAAA_0002) note_write(16, 32'hAAAA_0002);
        // `WRITE_TO(5'd16, 32'hAAAA_0003) note_write(16, 32'hAAAA_0003);
        // `WRITE_READ_TRANS
        // `READ_FROM(5'd16) chk_strict(expect_rd(16), data_out, "E2a: last write wins");
        // `READ_FROM(5'd17) chk_strict(expect_rd(17), data_out, "E2b: addr17 no spill -> 0");
        // `READ_FROM(5'd15) chk_strict(expect_rd(15), data_out, "E2c: addr15 no spill -> 0");

        // // E3: same-column unwritten partner. addr3=(0,3); addr8=(1,3).
        // `RESET gold_clear();
        // `RESET_WRITE_TRANS
        // `WRITE_TO(5'd3, 32'h0C01_0003) note_write(3, 32'h0C01_0003);
        // `WRITE_READ_TRANS
        // `READ_FROM(5'd8) chk_strict(expect_rd(8), data_out, "E3: same-column unwritten (1,3) -> 0");

        // // ╔══════════════════════════════════════════════════════════════════╗
        // // ║ GROUP F — FULL 25-CELL FILL & VERIFY                               ║
        // // ╚══════════════════════════════════════════════════════════════════╝
        // `RESET gold_clear();
        // `RESET_WRITE_TRANS
        // for (int a = 0; a < DEPTH; a++) begin
        //     `WRITE_TO(a[MEM_ADDRESS-1:0], (32'hC0DE_0000 | a)) note_write(a, 32'hC0DE_0000 | a);
        // end
        // `WRITE_READ_TRANS
        // for (int a = 0; a < DEPTH; a++) begin
        //     `READ_FROM(a[MEM_ADDRESS-1:0])
        //     chk_strict(expect_rd(a), data_out, $sformatf("F: full-fill verify addr %0d", a));
        // end

        // // F2: reverse overwrite, verify forward.
        // `READ_WRITE_TRANS
        // for (int a = DEPTH-1; a >= 0; a--) begin
        //     `WRITE_TO(a[MEM_ADDRESS-1:0], (32'h6EE6_0000 | a)) note_write(a, 32'h6EE6_0000 | a);
        // end
        // `WRITE_READ_TRANS
        // for (int a = 0; a < DEPTH; a++) begin
        //     `READ_FROM(a[MEM_ADDRESS-1:0])
        //     chk_strict(expect_rd(a), data_out, $sformatf("F2: reverse-fill verify addr %0d", a));
        // end

        // // ╔══════════════════════════════════════════════════════════════════╗
        // // ║ GROUP G — ADDRESS BOUNDARY & OUT-OF-BOUNDS                         ║
        // // ╚══════════════════════════════════════════════════════════════════╝
        // `RESET gold_clear();
        // `RESET_WRITE_TRANS
        // `WRITE_TO(5'd0,  32'hB0B0_0000) note_write(0,  32'hB0B0_0000);
        // `WRITE_TO(5'd24, 32'h0000_B0B0) note_write(24, 32'h0000_B0B0);
        // `WRITE_READ_TRANS
        // `READ_FROM(5'd0)  chk_strict(expect_rd(0),  data_out, "G1: min addr 0");
        // `READ_FROM(5'd24) chk_strict(expect_rd(24), data_out, "G2: max valid addr 24");

        // // G3..G5: OOB (row>=5) — demand a defined, safe 0 (no X leak).
        // `RESET gold_clear();
        // `RESET_WRITE_TRANS
        // `WRITE_TO(5'd25, 32'hDEAD_AA25)        // (5,0) OOB
        // `WRITE_TO(5'd29, 32'hDEAD_AA29)        // (5,4) OOB
        // `WRITE_TO(5'd31, 32'hDEAD_AA31)        // (6,1) OOB
        // `WRITE_READ_TRANS
        // `READ_FROM(5'd25) chk_strict(32'h0000_0000, data_out, "G3: OOB addr 25 -> defined 0");
        // `READ_FROM(5'd29) chk_strict(32'h0000_0000, data_out, "G4: OOB addr 29 -> defined 0");
        // `READ_FROM(5'd31) chk_strict(32'h0000_0000, data_out, "G5: OOB addr 31 -> defined 0");
        // // G6: legal (0,0) must stay clean despite OOB col0 writes.
        // `READ_FROM(5'd0)  chk_strict(expect_rd(0), data_out, "G6: legal (0,0) clean after OOB -> 0");

        // // ╔══════════════════════════════════════════════════════════════════╗
        // // ║ GROUP H — ASYNC RESET TIMING & GLITCHES                            ║
        // // ╚══════════════════════════════════════════════════════════════════╝
        // // H1: async assertion drives data_out=0 within 1ns, off any edge.
        // `RESET gold_clear();
        // `RESET_WRITE_TRANS
        // `WRITE_TO(5'd23, 32'hFACE_0023) note_write(23, 32'hFACE_0023);
        // `WRITE_READ_TRANS
        // `READ_FROM(5'd23) chk_strict(expect_rd(23), data_out, "H1a: value present before async rst");
        // @(negedge clk);
        // #(CLK_PERIOD*0.3);
        // rst = 1'b0; #1;
        // chk_strict(32'h0000_0000, data_out, "H1b: async rst zeroes data_out within 1ns");
        // rst = 1'b1; gold_clear(); `CLK_PERIOD_DEF

        // // H2: async rst right before a write commit -> write must NOT land.
        // `RESET gold_clear();
        // `RESET_WRITE_TRANS                         // in WRITE_STATE
        // wr_addr = 5'd19; data_in = 32'hBEEF_BABE;  // present bus, then kill with rst before posedge
        // #(CLK_PERIOD*0.3);
        // rst = 1'b0;
        // #(CLK_PERIOD*0.3);
        // rst = 1'b1;
        // `RESET gold_clear();
        // `RESET_READ_TRANS
        // `READ_FROM(5'd19) chk_strict(expect_rd(19), data_out, "H2: write killed by async rst -> 0");

        // // H3: sub-half-clock (1ns) glitch — informational.
        // `RESET gold_clear();
        // `RESET_WRITE_TRANS
        // `WRITE_TO(5'd20, 32'h1357_2468) note_write(20, 32'h1357_2468);
        // `WRITE_READ_TRANS
        // `READ_FROM(5'd20) chk_strict(expect_rd(20), data_out, "H3a: value before 1ns rst glitch");
        // @(negedge clk);
        // rst = 1'b0; #1; rst = 1'b1;
        // `READ_FROM(5'd20)
        // begin
        //     test_count++;
        //     $display("[INFO] Test %3d: 1ns rst glitch -> data_out=0x%08h (0=caught / %08h=filtered)",
        //              test_count, data_out, 32'h1357_2468);
        // end

        // // H4: triple reset then read old cell -> 0.
        // `RESET gold_clear();
        // `RESET_WRITE_TRANS
        // `WRITE_TO(5'd21, 32'hDECA_FBAD) note_write(21, 32'hDECA_FBAD);
        // `RESET `RESET `RESET gold_clear();
        // `RESET_READ_TRANS
        // `READ_FROM(5'd21) chk_strict(expect_rd(21), data_out, "H4: triple reset then read old -> 0");

        // // ╔══════════════════════════════════════════════════════════════════╗
        // // ║ GROUP I — EXPLICIT TRANSITION-MACRO COVERAGE                       ║
        // // ╚══════════════════════════════════════════════════════════════════╝
        // // I1: RESET_WRITE_TRANS commit.
        // `RESET gold_clear();
        // `RESET_WRITE_TRANS
        // `WRITE_TO(5'd4, 32'h0EDA_0004) note_write(4, 32'h0EDA_0004);
        // `WRITE_READ_TRANS
        // `READ_FROM(5'd4) chk_strict(expect_rd(4), data_out, "I1: RESET_WRITE_TRANS commit");

        // // I2: WRITE_READ_TRANS coherent read.
        // `RESET gold_clear();
        // `RESET_WRITE_TRANS
        // `WRITE_TO(5'd22, 32'hF00D_0022) note_write(22, 32'hF00D_0022);
        // `WRITE_READ_TRANS
        // `READ_FROM(5'd22) chk_strict(expect_rd(22), data_out, "I2: WRITE_READ_TRANS coherent read");

        // // I3: READ_WRITE_TRANS overwrite.
        // `RESET gold_clear();
        // `RESET_WRITE_TRANS
        // `WRITE_TO(5'd2, 32'hAAAA_0002) note_write(2, 32'hAAAA_0002);
        // `WRITE_READ_TRANS
        // `READ_FROM(5'd2) chk_strict(expect_rd(2), data_out, "I3a: pre READ_WRITE_TRANS");
        // `READ_WRITE_TRANS
        // `WRITE_TO(5'd2, 32'hBBBB_0002) note_write(2, 32'hBBBB_0002);
        // `WRITE_READ_TRANS
        // `READ_FROM(5'd2) chk_strict(expect_rd(2), data_out, "I3b: post READ_WRITE_TRANS overwrite");

        // // ╔══════════════════════════════════════════════════════════════════╗
        // // ║ GROUP J — RANDOMIZED STRESS (model-checked, dynamic transitions)   ║
        // // ╚══════════════════════════════════════════════════════════════════╝
        // `RESET gold_clear();
        // `RESET_READ_TRANS                          // start in READ
        // begin
        //     int op, a, in_write;
        //     logic [DATA_WIDTH-1:0] d;
        //     in_write = 0;                          // currently READ
        //     for (int n = 0; n < 120; n++) begin
        //         op = $urandom_range(0, 2);         // 0/1 = write, 2 = read
        //         a  = $urandom_range(0, DEPTH-1);
        //         if (op == 2) begin                 // ---- READ ----
        //             if (in_write) begin `WRITE_READ_TRANS end   // WRITE -> READ
        //             `READ_FROM(a[MEM_ADDRESS-1:0])
        //             chk_strict(expect_rd(a), data_out, $sformatf("J: rand read #%0d addr %0d", n, a));
        //             in_write = 0;
        //         end
        //         else begin                         // ---- WRITE ----
        //             if (!in_write) begin `READ_WRITE_TRANS end  // READ -> WRITE
        //             d = {$urandom} ^ 32'hA5A5_5A5A;
        //             `WRITE_TO(a[MEM_ADDRESS-1:0], d) note_write(a, d);
        //             in_write = 1;
        //         end
        //     end
        // end

        // ════════════════════════════════════════════════════════════════════
        `CLK_PERIOD_DEF
        $display("================================================================");
        $display("  RESULTS : %0d tests | %0d PASS | %0d FAIL",
                 test_count, pass_count, fail_count);
        if (fail_count == 0)
            $display("  DESIGN SURVIVED THE EVIL TB (unexpected!).");
        else
            $display("  DESIGN BROKEN: %0d adversarial checks exposed defects.", fail_count);
        $display("================================================================");
        $finish;
    end

endmodule