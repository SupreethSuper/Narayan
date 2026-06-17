`timescale 1ns/1ps
`include "nar_params.vh"

// ═══════════════════════════════════════════════════════════════════════════
//  tb_scratchpad_memory_v11  —  TB10 tests with TB9 timing-corrected structure
//
//  STRUCTURE:
//  - Uses TB9's mandated macros (RESET, READ, WRITE, transitions)
//  - Uses TB9's PRESENT macro to avoid spurious writes via stale bus
//  - Uses TB10's comprehensive test groups A-M
//  - Uses TB10's scoreboard and helper tasks
//  - Uses TB9's timing discipline + TB10's systematic coverage
// ═══════════════════════════════════════════════════════════════════════════

// ───────────────────────── MANDATED MACROS (TB9, verbatim) ───────────────────
`define CLK_PERIOD_DEF        \
    begin                     \
    @(posedge clk);           \
    @(negedge clk);           \
    end

`define RESET       \
    begin           \
    rst = 1'b0;     \
    `CLK_PERIOD_DEF \
    rst = 1'b1;     \
    `CLK_PERIOD_DEF \
    end

`define READ      \
    begin           \
    rw_ = 1'b1;     \
    `CLK_PERIOD_DEF \
    end

`define WRITE     \
    begin           \
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

`define SHOW_TIME \
    begin \
    $display("time: %t", $time); \
    end

// ───────────────────── TB HELPER MACRO (TB9 timing fix) ──────────────────────
// Present the bus to the intended target BEFORE entering WRITE_STATE
`define PRESENT(addr, data) \
    begin                   \
        wr_addr = addr;     \
        data_in = data;     \
    end

// ════════════════════════════════════════════════════════════════════════════
module tb_scratchpad_memoryv11;

    localparam DATA_WIDTH  = NAR_NUM_BITS;
    localparam ROWS        = NAR_MAT_ROWS;
    localparam COLS        = NAR_MAT_COLS;
    localparam MEM_ADDRESS = $clog2(ROWS * COLS);
    localparam DEPTH       = ROWS * COLS;
    localparam CLK_PERIOD  = 10;
    localparam RAND_ITERS  = 300;

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

    logic [DATA_WIDTH-1:0] gold [0:DEPTH-1];
    bit                    vld  [0:DEPTH-1];

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
        $dumpfile("tb_scratchpad_memoryv11.vcd");
        $dumpvars(0, tb_scratchpad_memoryv11);
    end

    initial begin
        #1000000;
        $display("[FATAL] Watchdog timeout — simulation hung");
        $finish;
    end

    // ───────────────────────── REPORTING TASKS ───────────────────────────────
    task automatic test_pass(string test_name);
        pass_count++;
        test_count++;
        $display("[PASS] Test %4d: %s", test_count, test_name);
    endtask

    task automatic test_fail(string test_name, string reason);
        fail_count++;
        test_count++;
        $display("[FAIL] Test %4d: %s | Reason: %s", test_count, test_name, reason);
    endtask

    task automatic check_equality(logic [DATA_WIDTH-1:0] expected, logic [DATA_WIDTH-1:0] actual, string test_name);
        if ($isunknown(actual)) begin
            test_fail(test_name, $sformatf("X/Z detected. Expected: 0x%h Actual: 0x%h", expected, actual));
        end
        else if (expected != actual) begin
            test_fail(test_name, $sformatf("Expected: 0x%h Actual: 0x%h", expected, actual));
        end
        else begin
            test_pass(test_name);
        end
    endtask

    // ───────────────────────── SCOREBOARD TASKS ──────────────────────────────
    task automatic sb_clear();
        for (int i = 0; i < DEPTH; i++) begin
            gold[i] = '0;
            vld[i]  = 1'b0;
        end
    endtask

    task automatic sb_write(int addr, logic [DATA_WIDTH-1:0] data);
        if ((addr >= 0) && (addr < DEPTH)) begin
            gold[addr] = data;
            vld[addr]  = 1'b1;
        end
    endtask

    function automatic logic [DATA_WIDTH-1:0] sb_expected(int addr);
        if ((addr >= 0) && (addr < DEPTH) && vld[addr])
            return gold[addr];
        else
            return '0;
    endfunction

    // ════════════════════════════════════════════════════════════════════════════
    initial begin
        rst = 1'b1; rw_ = 1'b1; cs = 1'b1; wr_addr = '0; data_in = '0;
        sb_clear();
        `RESET

        $display("================================================================");
        $display("  scratchpad_memory_v11  —  TB10 tests with TB9 timing fix");
        $display("  Address+mode set together BEFORE clock edge (no stale-bus issues)");
        $display("================================================================");

        // ╔══════════════════════════════════════════════════════════════════╗
        // ║ GROUP A — RESET AND READ-BEFORE-WRITE                             ║
        // ╚══════════════════════════════════════════════════════════════════╝
        `RESET sb_clear();
        // Set address AND mode combinatorially, then clock
        wr_addr = 5'd0; rw_ = 1'b1;
        `CLK_PERIOD_DEF
        check_equality(sb_expected(0), data_out, "A1: reset then read addr 0 -> zero");

        wr_addr = DEPTH-1; rw_ = 1'b1;
        `CLK_PERIOD_DEF
        check_equality(sb_expected(DEPTH-1), data_out, "A2: reset then read max addr -> zero");

        wr_addr = DEPTH/2; rw_ = 1'b1;
        `CLK_PERIOD_DEF
        check_equality(sb_expected(DEPTH/2), data_out, "A3: reset then read middle addr -> zero");

        // ╔══════════════════════════════════════════════════════════════════╗
        // ║ GROUP B — BASIC WRITE/READ                                        ║
        // ╚══════════════════════════════════════════════════════════════════╝
        `RESET sb_clear();
        `PRESENT(5'd0, 32'hDEAD_BEEF)
        `RESET_WRITE_TRANS
        `WRITE sb_write(0, 32'hDEAD_BEEF);
        // After WRITE_READ_TRANS, we're in READ at negedge. Set address + confirm mode combinatorially.
        `WRITE_READ_TRANS
        wr_addr = 5'd0; rw_ = 1'b1;
        `CLK_PERIOD_DEF
        check_equality(sb_expected(0), data_out, "B1: write/read addr 0");

        `RESET sb_clear();
        `PRESENT(DEPTH-1, 32'hFACE_CAFE)
        `RESET_WRITE_TRANS
        `WRITE sb_write(DEPTH-1, 32'hFACE_CAFE);
        `WRITE_READ_TRANS
        wr_addr = DEPTH-1; rw_ = 1'b1;
        `CLK_PERIOD_DEF
        check_equality(sb_expected(DEPTH-1), data_out, "B2: write/read max valid addr");

        `RESET sb_clear();
        `PRESENT(DEPTH/2, 32'h1234_5678)
        `RESET_WRITE_TRANS
        `WRITE sb_write(DEPTH/2, 32'h1234_5678);
        `WRITE_READ_TRANS
        wr_addr = DEPTH/2; rw_ = 1'b1;
        `CLK_PERIOD_DEF
        check_equality(sb_expected(DEPTH/2), data_out, "B3: write/read middle addr");

        // ╔══════════════════════════════════════════════════════════════════╗
        // ║ GROUP C — UNWRITTEN LOCATIONS REMAIN ZERO                         ║
        // ╚══════════════════════════════════════════════════════════════════╝
        `RESET sb_clear();
        `PRESENT(5'd0, 32'hAAAA_0000)
        `RESET_WRITE_TRANS
        `WRITE sb_write(0, 32'hAAAA_0000);
        `WRITE_READ_TRANS
        wr_addr = 5'd1; rw_ = 1'b1;
        `CLK_PERIOD_DEF
        check_equality(sb_expected(1), data_out, "C1: neighbor unwritten after addr0 write -> zero");

        wr_addr = DEPTH-1; rw_ = 1'b1;
        `CLK_PERIOD_DEF
        check_equality(sb_expected(DEPTH-1), data_out, "C2: distant unwritten after addr0 write -> zero");

        `RESET sb_clear();
        `PRESENT(5'd6, 32'h0000_BEEF)
        `RESET_WRITE_TRANS
        `WRITE sb_write(6, 32'h0000_BEEF);
        `WRITE_READ_TRANS
        wr_addr = 5'd5; rw_ = 1'b1;
        `CLK_PERIOD_DEF
        check_equality(sb_expected(5), data_out, "C3: same row/nearby unwritten -> zero");

        wr_addr = 5'd1; rw_ = 1'b1;
        `CLK_PERIOD_DEF
        check_equality(sb_expected(1), data_out, "C4: different row/col unwritten -> zero");

        // ╔══════════════════════════════════════════════════════════════════╗
        // ║ GROUP D — ROW/COLUMN ALIAS KILLER                                 ║
        // ║ (Catches the old broken check_zero_rows[row] && check_zero_cols   ║
        // ║  design with false-positive aliasing)                             ║
        // ╚══════════════════════════════════════════════════════════════════╝
        if (ROWS >= 2 && COLS >= 2) begin
            int a00, a11, a01, a10;
            a00 = 0*COLS + 0;
            a11 = 1*COLS + 1;
            a01 = 0*COLS + 1;
            a10 = 1*COLS + 0;

            `RESET sb_clear();
            `PRESENT(a00, 32'hA000_0000)
            `RESET_WRITE_TRANS
            `WRITE sb_write(a00, 32'hA000_0000);
            `PRESENT(a11, 32'hB111_1111)
            `WRITE
            sb_write(a11, 32'hB111_1111);
            `WRITE_READ_TRANS
            wr_addr = a00; rw_ = 1'b1;
            `CLK_PERIOD_DEF
            check_equality(sb_expected(a00), data_out, "D1: alias setup addr (0,0) valid");

            wr_addr = a11; rw_ = 1'b1;
            `CLK_PERIOD_DEF
            check_equality(sb_expected(a11), data_out, "D2: alias setup addr (1,1) valid");

            wr_addr = a01; rw_ = 1'b1;
            `CLK_PERIOD_DEF
            check_equality(sb_expected(a01), data_out, "D3: alias victim addr (0,1) must be zero");

            wr_addr = a10; rw_ = 1'b1;
            `CLK_PERIOD_DEF
            check_equality(sb_expected(a10), data_out, "D4: alias victim addr (1,0) must be zero");
        end

        // ╔══════════════════════════════════════════════════════════════════╗
        // ║ GROUP E — OVERWRITE BEHAVIOR / LAST WRITE WINS                    ║
        // ╚══════════════════════════════════════════════════════════════════╝
        `RESET sb_clear();
        `PRESENT(5'd3, 32'h1111_1111)
        `RESET_WRITE_TRANS
        `WRITE sb_write(3, 32'h1111_1111);
        `WRITE_READ_TRANS
        wr_addr = 5'd3; rw_ = 1'b1;
        `CLK_PERIOD_DEF
        check_equality(sb_expected(3), data_out, "E1: first write visible");

        `PRESENT(5'd3, 32'h2222_2222)
        `READ_WRITE_TRANS
        `WRITE sb_write(3, 32'h2222_2222);
        `WRITE_READ_TRANS
        wr_addr = 5'd3; rw_ = 1'b1;
        `CLK_PERIOD_DEF
        check_equality(sb_expected(3), data_out, "E2: second write overwrites first");

        `PRESENT(5'd3, 32'h3333_3333)
        `READ_WRITE_TRANS
        `WRITE sb_write(3, 32'h3333_3333);
        `WRITE_READ_TRANS
        wr_addr = 5'd3; rw_ = 1'b1;
        `CLK_PERIOD_DEF
        check_equality(sb_expected(3), data_out, "E3: third write overwrites second");

        wr_addr = 5'd2; rw_ = 1'b1;
        `CLK_PERIOD_DEF
        check_equality(sb_expected(2), data_out, "E4: adjacent lower addr remains zero");

        wr_addr = 5'd4; rw_ = 1'b1;
        `CLK_PERIOD_DEF
        check_equality(sb_expected(4), data_out, "E5: adjacent upper addr remains zero");

        // ╔══════════════════════════════════════════════════════════════════╗
        // ║ GROUP F — PATTERN TESTING                                         ║
        // ╚══════════════════════════════════════════════════════════════════╝
        `RESET sb_clear();
        `PRESENT(5'd7, 32'h0000_0000)
        `RESET_WRITE_TRANS
        `WRITE sb_write(7, 32'h0000_0000);
        `WRITE_READ_TRANS
        wr_addr = 5'd7; rw_ = 1'b1;
        `CLK_PERIOD_DEF
        check_equality(sb_expected(7), data_out, "F1: pattern zero");

        `PRESENT(5'd7, 32'hFFFF_FFFF)
        `READ_WRITE_TRANS
        `WRITE sb_write(7, 32'hFFFF_FFFF);
        `WRITE_READ_TRANS
        wr_addr = 5'd7; rw_ = 1'b1;
        `CLK_PERIOD_DEF
        check_equality(sb_expected(7), data_out, "F2: pattern all ones");

        `PRESENT(5'd7, 32'hAAAA_AAAA)
        `READ_WRITE_TRANS
        `WRITE sb_write(7, 32'hAAAA_AAAA);
        `WRITE_READ_TRANS
        wr_addr = 5'd7; rw_ = 1'b1;
        `CLK_PERIOD_DEF
        check_equality(sb_expected(7), data_out, "F3: pattern alternating A");

        `PRESENT(5'd7, 32'h5555_5555)
        `READ_WRITE_TRANS
        `WRITE sb_write(7, 32'h5555_5555);
        `WRITE_READ_TRANS
        wr_addr = 5'd7; rw_ = 1'b1;
        `CLK_PERIOD_DEF
        check_equality(sb_expected(7), data_out, "F4: pattern alternating 5");

        `PRESENT(5'd7, 32'h8000_0001)
        `READ_WRITE_TRANS
        `WRITE sb_write(7, 32'h8000_0001);
        `WRITE_READ_TRANS
        wr_addr = 5'd7; rw_ = 1'b1;
        `CLK_PERIOD_DEF
        check_equality(sb_expected(7), data_out, "F5: pattern MSB/LSB set");

        // ╔══════════════════════════════════════════════════════════════════╗
        // ║ GROUP G — CHIP SELECT BEHAVIOR                                    ║
        // ╚══════════════════════════════════════════════════════════════════╝
        `RESET sb_clear();
        `CS_OFF
        `PRESENT(5'd8, 32'hBAD0_C0DE)
        `RESET_WRITE_TRANS
        `WRITE
        // Note: write while cs=0, not noted in scoreboard
        `CS_ON
        `WRITE_READ_TRANS
        wr_addr = 5'd8; rw_ = 1'b1;
        `CLK_PERIOD_DEF
        `SHOW_TIME
        check_equality(sb_expected(8), data_out, "G1: write while cs=0 must not commit");
        `SHOW_TIME

        `RESET sb_clear();
        `PRESENT(5'd9, 32'hCAFE_0009)
        `RESET_WRITE_TRANS
        `WRITE sb_write(9, 32'hCAFE_0009);
        `WRITE_READ_TRANS
        wr_addr = 5'd9; rw_ = 1'b1;
        `CLK_PERIOD_DEF
        check_equality(sb_expected(9), data_out, "G2: baseline valid write before cs-off read");

        `CS_OFF
        wr_addr = 5'd9; rw_ = 1'b1;
        `CLK_PERIOD_DEF
        check_equality(32'h0000_0000, data_out, "G3: read while cs=0 forces output zero");

        `CS_ON
        wr_addr = 5'd9; rw_ = 1'b1;
        `CLK_PERIOD_DEF
        check_equality(sb_expected(9), data_out, "G4: data preserved after cs re-enabled");

        // ╔══════════════════════════════════════════════════════════════════╗
        // ║ GROUP H — RESET DESTROYS LOGICAL VALIDITY                         ║
        // ╚══════════════════════════════════════════════════════════════════╝
        `RESET sb_clear();
        `PRESENT(5'd10, 32'hABCD_1234)
        `RESET_WRITE_TRANS
        `WRITE sb_write(10, 32'hABCD_1234);
        `WRITE_READ_TRANS
        wr_addr = 5'd10; rw_ = 1'b1;
        `CLK_PERIOD_DEF
        check_equality(sb_expected(10), data_out, "H1: value readable before reset");

        `RESET sb_clear();
        wr_addr = 5'd10; rw_ = 1'b1;
        `CLK_PERIOD_DEF
        check_equality(sb_expected(10), data_out, "H2: old addr reads zero after reset");

        `PRESENT(5'd11, 32'h0000_0001)
        `RESET_WRITE_TRANS
        `WRITE sb_write(11, 32'h0000_0001);
        `WRITE_READ_TRANS
        wr_addr = 5'd11; rw_ = 1'b1;
        `CLK_PERIOD_DEF
        check_equality(sb_expected(11), data_out, "H3: new post-reset write readable");

        wr_addr = 5'd10; rw_ = 1'b1;
        `CLK_PERIOD_DEF
        check_equality(sb_expected(10), data_out, "H4: old pre-reset addr still zero after unrelated write");

        // ╔══════════════════════════════════════════════════════════════════╗
        // ║ GROUP I — FULL FILL AND VERIFY                                    ║
        // ╚══════════════════════════════════════════════════════════════════╝
        `RESET sb_clear();
        `PRESENT(5'd0, 32'hC0DE_0000)
        `RESET_WRITE_TRANS
        for (int a = 0; a < DEPTH; a++) begin
            `PRESENT(a, (32'hC0DE_0000 ^ a))
            `WRITE
            `WRITE  // Hold write for a clean commit cycle
            sb_write(a, 32'hC0DE_0000 ^ a);
        end
        `WRITE_READ_TRANS
        for (int a = 0; a < DEPTH; a++) begin
            wr_addr = a; rw_ = 1'b1;
            `CLK_PERIOD_DEF
            check_equality(sb_expected(a), data_out, $sformatf("I1: full-fill verify addr %0d", a));
        end

        // ╔══════════════════════════════════════════════════════════════════╗
        // ║ GROUP J — REVERSE OVERWRITE FULL MEMORY                           ║
        // ╚══════════════════════════════════════════════════════════════════╝
        `PRESENT(DEPTH-1, (32'h6EE6_0000 | (DEPTH-1)))
        `READ_WRITE_TRANS
        for (int a = DEPTH-1; a >= 0; a--) begin
            `PRESENT(a, (32'h6EE6_0000 | a))
            `WRITE
            `WRITE  // Hold write for a clean commit cycle
            sb_write(a, 32'h6EE6_0000 | a);
        end
        `WRITE_READ_TRANS
        for (int a = 0; a < DEPTH; a++) begin
            wr_addr = a; rw_ = 1'b1;
            `CLK_PERIOD_DEF
            check_equality(sb_expected(a), data_out, $sformatf("J1: reverse overwrite verify addr %0d", a));
        end

        // ╔══════════════════════════════════════════════════════════════════╗
        // ║ GROUP K — MULTIPLE RESETS                                         ║
        // ╚══════════════════════════════════════════════════════════════════╝
        `RESET sb_clear();
        `PRESENT(5'd12, 32'hDADA_1212)
        `RESET_WRITE_TRANS
        `WRITE sb_write(12, 32'hDADA_1212);
        `WRITE_READ_TRANS
        wr_addr = 5'd12; rw_ = 1'b1;
        `CLK_PERIOD_DEF
        check_equality(sb_expected(12), data_out, "K1: value readable before multi-reset");

        `RESET sb_clear();
        `RESET sb_clear();
        `RESET sb_clear();
        wr_addr = 5'd12; rw_ = 1'b1;
        `CLK_PERIOD_DEF
        check_equality(sb_expected(12), data_out, "K2: old value gone after triple reset");

        `PRESENT(5'd12, 32'hBBBB_1212)
        `READ_WRITE_TRANS
        `WRITE
        `WRITE  // Hold write for a clean commit cycle
        sb_write(12, 32'hBBBB_1212);
        `WRITE_READ_TRANS
        wr_addr = 5'd12; rw_ = 1'b1;
        `CLK_PERIOD_DEF
        check_equality(sb_expected(12), data_out, "K3: same addr writable after triple reset");

        // ╔══════════════════════════════════════════════════════════════════╗
        // ║ GROUP L — RANDOM MODEL-CHECKED STRESS                             ║
        // ╚══════════════════════════════════════════════════════════════════╝
        `RESET sb_clear();
        `RESET_READ_TRANS
        begin
            int op, addr;
            logic [DATA_WIDTH-1:0] data;
            for (int n = 0; n < RAND_ITERS; n++) begin
                op   = $urandom_range(0, 3);
                addr = $urandom_range(0, DEPTH-1);
                data = {$urandom} ^ (32'hA5A5_5A5A + n);

                case (op)
                    0, 1: begin
                        // ---- RANDOM WRITE ----
                        `PRESENT(addr, data)
                        rw_ = 1'b0;
                        `CLK_PERIOD_DEF
                        `WRITE  // Hold write for commit
                        sb_write(addr, data);
                    end

                    2: begin
                        // ---- RANDOM READ ----
                        wr_addr = addr; rw_ = 1'b1;
                        `CLK_PERIOD_DEF
                        check_equality(sb_expected(addr), data_out,
                            $sformatf("L: random read iter %0d addr %0d", n, addr));
                    end

                    3: begin
                        // ---- OCCASIONAL RESET ----
                        `RESET
                        sb_clear();
                        wr_addr = addr; rw_ = 1'b1;
                        `CLK_PERIOD_DEF
                        check_equality(sb_expected(addr), data_out,
                            $sformatf("L: random post-reset read iter %0d addr %0d", n, addr));
                    end
                endcase
            end
        end

        // ─── Final sweep after random stress ───
        for (int a = 0; a < DEPTH; a++) begin
            wr_addr = a; rw_ = 1'b1;
            `CLK_PERIOD_DEF
            check_equality(sb_expected(a), data_out, $sformatf("L-final: scoreboard sweep addr %0d", a));
        end

        // ════════════════════════════════════════════════════════════════════
        `CLK_PERIOD_DEF
        $display("================================================================");
        $display("  RESULTS : %0d tests | %0d PASS | %0d FAIL",
                 test_count, pass_count, fail_count);
        if (fail_count == 0)
            $display("  REGRESSION PASSED — DESIGN SURVIVED.");
        else
            $display("  %0d checks failed — investigate DUT defects.", fail_count);
        $display("================================================================");
        $finish;
    end

endmodule
