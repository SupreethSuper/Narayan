`timescale 1ns/1ps
`include "nar_params.vh"
`include "scheduler_params.vh"

module scheduler_tb;

    // ----------------------------------------------------------------
    // Parameters (mirror DUT)
    // ----------------------------------------------------------------
    localparam DATA_WIDTH  = NAR_NUM_BITS;
    localparam ROWS        = NAR_MAT_ROWS;
    localparam COLS        = NAR_MAT_COLS;
    localparam NUM_UNITS   = SCHED_MEM_UNITS;
    localparam LOCAL_ADDR  = $clog2(ROWS * COLS);
    localparam GLOBAL_ADDR = $clog2(NUM_UNITS * ROWS * COLS);
    localparam TOTAL_ADDRS = NUM_UNITS * ROWS * COLS;  // 100

    // ----------------------------------------------------------------
    // DUT signals
    // ----------------------------------------------------------------
    logic                   clk;
    logic                   rw_;
    logic                   cs;
    logic                   rst;
    logic [DATA_WIDTH-1:0]  data_in;
    logic [DATA_WIDTH-1:0]  data_out;
    logic [NUM_UNITS-1:0]   cs_out;
    logic [LOCAL_ADDR-1:0]  rd_addr;
    logic                   rw_out;
    logic                   rst_out;

    // ----------------------------------------------------------------
    // DUT instantiation
    // ----------------------------------------------------------------
    scheduler #(
        .DATA_WIDTH (DATA_WIDTH),
        .ROWS       (ROWS),
        .COLS       (COLS),
        .NUM_UNITS  (NUM_UNITS)
    ) dut (
        .clk     (clk),
        .rw_     (rw_),
        .cs      (cs),
        .rst     (rst),
        .data_in (data_in),
        .data_out(data_out),
        .cs_out  (cs_out),
        .rd_addr (rd_addr),
        .rw_out  (rw_out),
        .rst_out (rst_out)
    );

    // 10 ns clock
    initial clk = 0;
    always #5 clk = ~clk;

    int errors = 0;

    // ----------------------------------------------------------------
    // Helper: reset DUT and leave it ready for writes (beat_cnt = 0)
    // ----------------------------------------------------------------
    task automatic do_reset();
        rst = 0; cs = 0; rw_ = 1;
        @(posedge clk); #1;
        rst = 1;
        #1;
    endtask

    // ----------------------------------------------------------------
    // Helper: check cs_out and rd_addr for a given beat number
    // ----------------------------------------------------------------
    task automatic check_beat(input int beat);
        int exp_super_row, exp_pos, exp_mem, exp_col, exp_local;
        logic [NUM_UNITS-1:0] exp_cs;

        exp_super_row = beat / (NUM_UNITS * COLS);
        exp_pos       = beat % (NUM_UNITS * COLS);
        exp_mem       = exp_pos / COLS;
        exp_col       = exp_pos % COLS;
        exp_local     = exp_super_row * COLS + exp_col;
        exp_cs        = NUM_UNITS'(1 << exp_mem);

        if (cs_out !== exp_cs) begin
            $display("[FAIL] beat=%3d: cs_out=4'b%04b  expected=4'b%04b  (mem%0d)",
                     beat, cs_out, exp_cs, exp_mem);
            errors++;
        end
        if (rd_addr !== LOCAL_ADDR'(exp_local)) begin
            $display("[FAIL] beat=%3d: rd_addr=%2d  expected=%2d  (row%0d col%0d)",
                     beat, rd_addr, exp_local, exp_super_row, exp_col);
            errors++;
        end
    endtask

    // ----------------------------------------------------------------
    // Stimulus
    // ----------------------------------------------------------------
    initial begin
        $dumpfile("scheduler_tb.vcd");
        $dumpvars(0, scheduler_tb);

        cs      = 0;
        rw_     = 1;
        rst     = 0;
        data_in = '0;

        // --------------------------------------------------------
        // Test 1: Pass-throughs (data_out, rw_out, rst_out)
        // --------------------------------------------------------
        $display("");
        $display("=== Test 1: Pass-throughs ===");
        data_in = 32'hDEAD_BEEF;
        rw_     = 1;
        rst     = 0;
        #1;
        if (data_out !== data_in) begin
            $display("[FAIL] data_out=0x%h  expected=0x%h", data_out, data_in);
            errors++;
        end
        if (rw_out !== rw_) begin
            $display("[FAIL] rw_out=%b  expected=%b", rw_out, rw_);
            errors++;
        end
        if (rst_out !== rst) begin
            $display("[FAIL] rst_out=%b  expected=%b", rst_out, rst);
            errors++;
        end
        if (errors == 0) $display("[PASS] All pass-throughs correct");
        data_in = '0;

        // --------------------------------------------------------
        // Test 2: cs=0 must keep cs_out all-zero AND not advance counter
        // --------------------------------------------------------
        $display("");
        $display("=== Test 2: cs=0 gates cs_out, counter frozen ===");
        do_reset();
        cs = 0; rw_ = 0;
        repeat (5) begin
            @(posedge clk); #1;
            if (cs_out !== '0) begin
                $display("[FAIL] cs=0 but cs_out=4'b%04b", cs_out);
                errors++;
            end
        end
        // Counter should still be 0 — verify with check_beat(0)
        cs = 1; rw_ = 0; #1;
        if (cs_out !== NUM_UNITS'(1 << 0)) begin
            $display("[FAIL] Counter advanced while cs=0");
            errors++;
        end
        if (errors == 0) $display("[PASS] cs=0 freezes counter and gates cs_out");

        // --------------------------------------------------------
        // Test 3: Full 100-beat write sweep
        // Check cs_out and rd_addr BEFORE each clock edge (they
        // reflect the current beat_cnt combinationally).
        // --------------------------------------------------------
        $display("");
        $display("=== Test 3: Full write sweep (100 beats) ===");
        do_reset();
        cs = 1; rw_ = 0;
        #1; // combinational settle

        for (int beat = 0; beat < TOTAL_ADDRS; beat++) begin
            check_beat(beat);    // sample outputs before clock
            @(posedge clk); #1; // advance beat_cnt
        end
        if (errors == 0)
            $display("[PASS] All %0d beats decoded correctly", TOTAL_ADDRS);

        // --------------------------------------------------------
        // Test 4: Wrap-around — after beat 99, counter rolls to 0
        // (the 100th posedge in test 3 triggered the wrap)
        // --------------------------------------------------------
        $display("");
        $display("=== Test 4: Wrap-around (beat 99 -> 0) ===");
        check_beat(0);
        if (errors == 0) $display("[PASS] Counter wrapped back to beat 0");

        // --------------------------------------------------------
        // Test 5: Spot-check printout at key transition beats
        // beat_cnt is at 0 coming in (from wrap-around above, no
        // extra clocks applied since test 4's check)
        // --------------------------------------------------------
        $display("");
        $display("=== Test 5: Spot-check at row/mem boundaries ===");
        $display("  beat | cs_out | rd_addr | mem | row | col");

        begin
            int spots[10] = '{0, 4, 5, 19, 20, 24, 25, 39, 95, 99};
            int prev = 0;
            foreach (spots[k]) begin
                automatic int tgt = spots[k];
                // Advance counter from prev to tgt
                repeat (tgt - prev) begin @(posedge clk); #1; end
                begin
                    automatic int sr = tgt / (NUM_UNITS * COLS);
                    automatic int ps = tgt % (NUM_UNITS * COLS);
                    automatic int mi = ps / COLS;
                    automatic int ci = ps % COLS;
                    $display("   %3d |   %04b |     %3d | mem%0d | row%0d | col%0d",
                             tgt, cs_out, rd_addr, mi, sr, ci);
                end
                prev = tgt;
            end
        end

        // --------------------------------------------------------
        $display("");
        $display("========================================");
        if (errors == 0)
            $display("RESULT: ALL TESTS PASSED");
        else
            $display("RESULT: %0d FAILURE(S) DETECTED", errors);
        $display("========================================");
        $finish;
    end

endmodule
