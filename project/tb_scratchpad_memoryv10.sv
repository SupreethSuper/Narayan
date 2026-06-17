`timescale 1ns/1ps
`include "nar_params.vh"

// =============================================================================
// Regression-level scratchpad memory testbench
//
// Requirements honored:
// - Uses direct macros: `RESET, `READ, `WRITE
// - Does not directly drive rst/rw_ in test sequences
// - Uses scoreboard
// - Detects X leaks
// - Tests reset behavior, CS gating, overwrite, full fill, random stress
// =============================================================================

// -----------------------------------------------------------------------------
// Required direct macros
// -----------------------------------------------------------------------------

`define CLK_PERIOD_DEF        \
    begin                     \
        @(posedge clk);       \
        @(negedge clk);       \
    end

`define RESET                 \
    begin                     \
        rst = 1'b0;           \
        `CLK_PERIOD_DEF       \
        rst = 1'b1;           \
        `CLK_PERIOD_DEF       \
    end

`define READ                  \
    begin                     \
        rw_ = 1'b1;           \
        `CLK_PERIOD_DEF       \
    end

`define WRITE                 \
    begin                     \
        rw_ = 1'b0;           \
        `CLK_PERIOD_DEF       \
    end

// -----------------------------------------------------------------------------
// Testbench
// -----------------------------------------------------------------------------

module tb_scratchpad_memoryv10;

    // =========================================================================
    // Parameters
    // =========================================================================

    localparam DATA_WIDTH  = NAR_NUM_BITS;
    localparam ROWS        = NAR_MAT_ROWS;
    localparam COLS        = NAR_MAT_COLS;
    localparam MEM_ADDRESS = $clog2(ROWS * COLS);
    localparam DEPTH       = ROWS * COLS;
    localparam CLK_PERIOD  = 10;

    localparam RAND_ITERS  = 300;

    // =========================================================================
    // DUT signals
    // =========================================================================

    logic clk;
    logic rst;
    logic rw_;
    logic cs;
    logic [MEM_ADDRESS-1:0] wr_addr;
    logic [DATA_WIDTH-1:0]  data_in;
    logic [DATA_WIDTH-1:0]  data_out;

    // =========================================================================
    // Counters
    // =========================================================================

    integer test_count = 0;
    integer pass_count = 0;
    integer fail_count = 0;

    // =========================================================================
    // Scoreboard
    // =========================================================================

    logic [DATA_WIDTH-1:0] gold [0:DEPTH-1];
    bit                    vld  [0:DEPTH-1];

    // =========================================================================
    // DUT
    // =========================================================================

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

    // =========================================================================
    // Clock
    // =========================================================================

    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // =========================================================================
    // Waveforms
    // =========================================================================

    initial begin
        $dumpfile("tb_scratchpad_memoryv10.vcd");
        $dumpvars(0, tb_scratchpad_memoryv10);
    end

    // =========================================================================
    // Watchdog
    // =========================================================================

    initial begin
        #1000000;
        $display("[FATAL] Watchdog timeout. Simulation hung.");
        $finish;
    end

    // =========================================================================
    // Reporting helpers
    // =========================================================================

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

    task automatic check_equality(
        input logic [DATA_WIDTH-1:0] expected,
        input logic [DATA_WIDTH-1:0] actual,
        input string                 test_name
    );
        if ($isunknown(actual)) begin
            test_fail(test_name, $sformatf("Actual has X/Z. Expected=0x%h Actual=0x%h",
                                           expected, actual));
        end
        else if (actual !== expected) begin
            test_fail(test_name, $sformatf("Expected=0x%h Actual=0x%h",
                                           expected, actual));
        end
        else begin
            test_pass(test_name);
        end
    endtask

    // =========================================================================
    // Scoreboard helpers
    // =========================================================================

    task automatic sb_clear();
        for (int i = 0; i < DEPTH; i++) begin
            gold[i] = '0;
            vld[i]  = 1'b0;
        end
    endtask

    task automatic sb_write(
        input int                    addr,
        input logic [DATA_WIDTH-1:0] data
    );
        if ((addr >= 0) && (addr < DEPTH)) begin
            gold[addr] = data;
            vld[addr]  = 1'b1;
        end
    endtask

    function automatic logic [DATA_WIDTH-1:0] sb_expected(input int addr);
        if ((addr >= 0) && (addr < DEPTH) && vld[addr])
            return gold[addr];
        else
            return '0;
    endfunction

    // =========================================================================
    // Bus/control helpers
    //
    // Important:
    // These helpers use `READ, `WRITE, and `RESET.
    // They do not directly assign rw_ or rst.
    // =========================================================================

    task automatic init_tb();
        cs      = 1'b1;
        wr_addr = '0;
        data_in = '0;

        // These two are only initial known-state setup before real stimulus.
        // Actual test sequencing uses `RESET, `READ, `WRITE.
        rst     = 1'b1;
        rw_     = 1'b1;

        sb_clear();
        `RESET
        `READ
    endtask

    task automatic apply_reset();
        `RESET
        sb_clear();
        `READ
    endtask

    task automatic cs_on();
        cs = 1'b1;
        `CLK_PERIOD_DEF
    endtask

    task automatic cs_off();
        cs = 1'b0;
        `CLK_PERIOD_DEF
    endtask

    task automatic present_write(
        input logic [MEM_ADDRESS-1:0] addr,
        input logic [DATA_WIDTH-1:0]  data
    );
        // Present address/data before entering WRITE mode.
        wr_addr = addr;
        data_in = data;
        `CLK_PERIOD_DEF
    endtask

    task automatic do_write(
        input int                    addr,
        input logic [DATA_WIDTH-1:0] data,
        input bit                    should_commit
    );
        present_write(addr[MEM_ADDRESS-1:0], data);

        `WRITE

        // Hold write mode for one extra full cycle so FSM-based registered write
        // designs get a clean commit cycle.
        `WRITE

        if (should_commit)
            sb_write(addr, data);
    endtask

    task automatic do_read_check(
        input int    addr,
        input string test_name
    );
        wr_addr = addr[MEM_ADDRESS-1:0];

        `CLK_PERIOD_DEF

        // Registered read port latency allowance.
        `READ

        check_equality(sb_expected(addr), data_out, test_name);
    endtask

    task automatic do_read_expect(
        input int                    addr,
        input logic [DATA_WIDTH-1:0] expected,
        input string                 test_name
    );
        wr_addr = addr[MEM_ADDRESS-1:0];

        `READ
        `READ

        check_equality(expected, data_out, test_name);
    endtask

    // =========================================================================
    // Main regression
    // =========================================================================

    initial begin
        init_tb();

        $display("================================================================");
        $display(" scratchpad_memory regression testbench");
        $display(" DATA_WIDTH=%0d ROWS=%0d COLS=%0d DEPTH=%0d ADDR_BITS=%0d",
                 DATA_WIDTH, ROWS, COLS, DEPTH, MEM_ADDRESS);
        $display("================================================================");

        // =====================================================================
        // GROUP A: Reset and read-before-write
        // =====================================================================

        apply_reset();
        do_read_check(0, "A1: reset then read addr 0 -> zero");
        do_read_check(DEPTH-1, "A2: reset then read max addr -> zero");
        do_read_check(DEPTH/2, "A3: reset then read middle addr -> zero");

        // =====================================================================
        // GROUP B: Basic write/read
        // =====================================================================

        apply_reset();
        do_write(0, 32'hDEAD_BEEF, 1'b1);
        do_read_check(0, "B1: write/read addr 0");

        apply_reset();
        do_write(DEPTH-1, 32'hFACE_CAFE, 1'b1);
        do_read_check(DEPTH-1, "B2: write/read max valid addr");

        apply_reset();
        do_write(DEPTH/2, 32'h1234_5678, 1'b1);
        do_read_check(DEPTH/2, "B3: write/read middle addr");

        // =====================================================================
        // GROUP C: Unwritten locations remain zero
        // =====================================================================

        apply_reset();
        do_write(0, 32'hAAAA_0000, 1'b1);
        $display("time :%t", $time);
        do_read_check(1, "C1: neighbor unwritten after addr0 write -> zero");
        $display("time :%t", $time);
        do_read_check(DEPTH-1, "C2: distant unwritten after addr0 write -> zero");

        apply_reset();
        do_write(6, 32'h0000_BEEF, 1'b1);
        do_read_check(5, "C3: same row/nearby unwritten -> zero");
        do_read_check(1, "C4: different row/col unwritten -> zero");

        // =====================================================================
        // GROUP D: Row/column alias killer
        //
        // This specifically catches the old broken check_zero_rows[row] &&
        // check_zero_cols[col] design.
        // =====================================================================

        if (ROWS >= 2 && COLS >= 2) begin
            int a00;
            int a11;
            int a01;
            int a10;

            a00 = 0*COLS + 0;
            a11 = 1*COLS + 1;
            a01 = 0*COLS + 1;
            a10 = 1*COLS + 0;

            apply_reset();

            do_write(a00, 32'hA000_0000, 1'b1);
            do_write(a11, 32'hB111_1111, 1'b1);

            do_read_check(a00, "D1: alias setup addr (0,0) valid");
            do_read_check(a11, "D2: alias setup addr (1,1) valid");
            do_read_check(a01, "D3: alias victim addr (0,1) must be zero");
            do_read_check(a10, "D4: alias victim addr (1,0) must be zero");
        end

        // =====================================================================
        // GROUP E: Overwrite behavior / last write wins
        // =====================================================================

        apply_reset();

        do_write(3, 32'h1111_1111, 1'b1);
        do_read_check(3, "E1: first write visible");

        do_write(3, 32'h2222_2222, 1'b1);
        do_read_check(3, "E2: second write overwrites first");

        do_write(3, 32'h3333_3333, 1'b1);
        do_read_check(3, "E3: third write overwrites second");

        do_read_check(2, "E4: adjacent lower addr remains zero");
        do_read_check(4, "E5: adjacent upper addr remains zero");

        // =====================================================================
        // GROUP F: Pattern testing
        // =====================================================================

        apply_reset();

        do_write(7, 32'h0000_0000, 1'b1);
        do_read_check(7, "F1: pattern zero");

        do_write(7, 32'hFFFF_FFFF, 1'b1);
        do_read_check(7, "F2: pattern all ones");

        do_write(7, 32'hAAAA_AAAA, 1'b1);
        do_read_check(7, "F3: pattern alternating A");

        do_write(7, 32'h5555_5555, 1'b1);
        do_read_check(7, "F4: pattern alternating 5");

        do_write(7, 32'h8000_0001, 1'b1);
        do_read_check(7, "F5: pattern MSB/LSB set");

        // =====================================================================
        // GROUP G: Chip select behavior
        // =====================================================================

        apply_reset();

        cs_off();
        do_write(8, 32'hBAD0_C0DE, 1'b0);
        cs_on();
        do_read_check(8, "G1: write while cs=0 must not commit");

        apply_reset();

        do_write(9, 32'hCAFE_0009, 1'b1);
        do_read_check(9, "G2: baseline valid write before cs-off read");

        cs_off();
        do_read_expect(9, '0, "G3: read while cs=0 forces output zero");

        cs_on();
        do_read_check(9, "G4: data preserved after cs re-enabled");

        // =====================================================================
        // GROUP H: Reset destroys logical validity
        //
        // With epoch-tag design, old physical memory may still contain data,
        // but it must not be logically readable after reset.
        // =====================================================================

        apply_reset();

        do_write(10, 32'hABCD_1234, 1'b1);
        do_read_check(10, "H1: value readable before reset");

        apply_reset();
        do_read_check(10, "H2: old addr reads zero after reset");

        do_write(11, 32'h0000_0001, 1'b1);
        do_read_check(11, "H3: new post-reset write readable");
        do_read_check(10, "H4: old pre-reset addr still zero after unrelated write");

        // =====================================================================
        // GROUP I: Full fill and verify
        // =====================================================================

        apply_reset();

        for (int a = 0; a < DEPTH; a++) begin
            do_write(a, 32'hC0DE_0000 ^ a, 1'b1);
        end

        for (int a = 0; a < DEPTH; a++) begin
            do_read_check(a, $sformatf("I1: full-fill verify addr %0d", a));
        end

        // =====================================================================
        // GROUP J: Reverse overwrite full memory
        // =====================================================================

        for (int a = DEPTH-1; a >= 0; a--) begin
            do_write(a, 32'h6EE6_0000 | a, 1'b1);
        end

        for (int a = 0; a < DEPTH; a++) begin
            do_read_check(a, $sformatf("J1: reverse overwrite verify addr %0d", a));
        end

        // =====================================================================
        // GROUP K: Multiple resets
        // =====================================================================

        apply_reset();

        do_write(12, 32'hDADA_1212, 1'b1);
        do_read_check(12, "K1: value readable before multi-reset");

        apply_reset();
        apply_reset();
        apply_reset();

        do_read_check(12, "K2: old value gone after triple reset");

        do_write(12, 32'hBBBB_1212, 1'b1);
        do_read_check(12, "K3: same addr writable after triple reset");

        // =====================================================================
        // GROUP L: Random model-checked stress
        // =====================================================================

        apply_reset();

        for (int n = 0; n < RAND_ITERS; n++) begin
            int op;
            int addr;
            logic [DATA_WIDTH-1:0] data;

            op   = $urandom_range(0, 3);
            addr = $urandom_range(0, DEPTH-1);
            data = {$urandom} ^ (32'hA5A5_5A5A + n);

            case (op)

                0, 1: begin
                    do_write(addr, data, 1'b1);
                end

                2: begin
                    do_read_check(addr, $sformatf("L: random read iter %0d addr %0d", n, addr));
                end

                3: begin
                    // occasional reset inside random stream
                    apply_reset();
                    do_read_check(addr, $sformatf("L: random post-reset read iter %0d addr %0d", n, addr));
                end

            endcase
        end

        // Final sweep after random stress.
        for (int a = 0; a < DEPTH; a++) begin
            do_read_check(a, $sformatf("L-final: scoreboard sweep addr %0d", a));
        end

        // =====================================================================
        // Optional OOB tests
        //
        // Enable only if DUT explicitly guards row/col bounds.
        // Your earlier design did not safely guard addr >= DEPTH.
        // =====================================================================

`ifdef CHECK_OOB_SAFE
        apply_reset();

        do_write(DEPTH, 32'hDEAD_0025, 1'b0);
        do_read_expect(DEPTH, '0, "M1: OOB addr DEPTH returns zero");

        do_write((1 << MEM_ADDRESS)-1, 32'hDEAD_0031, 1'b0);
        do_read_expect((1 << MEM_ADDRESS)-1, '0, "M2: max encoded OOB addr returns zero");
`endif

        // =====================================================================
        // Summary
        // =====================================================================

        `CLK_PERIOD_DEF

        $display("================================================================");
        $display(" RESULTS: %0d tests | %0d PASS | %0d FAIL",
                 test_count, pass_count, fail_count);

        if (fail_count == 0) begin
            $display(" REGRESSION PASSED");
        end
        else begin
            $display(" REGRESSION FAILED");
        end

        $display("================================================================");

        $finish;
    end

endmodule