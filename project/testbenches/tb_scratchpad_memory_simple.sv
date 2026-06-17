`include "nar_params.vh"
`timescale 1ns/1ps

module tb_scratchpad_memory_simple;

    localparam DATA_WIDTH      = NAR_NUM_BITS;
    localparam ROWS            = NAR_MAT_ROWS;
    localparam COLS            = NAR_MAT_COLS;
    localparam MEM_ADDRESS     = $clog2(ROWS * COLS);
    localparam CLK_PERIOD      = 10;

    logic clk, rst, rw_, cs;
    logic [MEM_ADDRESS-1:0] wr_addr;
    logic [DATA_WIDTH-1:0] data_in, data_out;

    integer test_count = 0, pass_count = 0, fail_count = 0;

    scratchpad_memory #(
        .DATA_WIDTH(DATA_WIDTH),
        .ROWS(ROWS),
        .COLS(COLS),
        .MEM_ADDRESS(MEM_ADDRESS)
    ) dut (
        .clk(clk), .rst(rst), .rw_(rw_), .cs(cs),
        .wr_addr(wr_addr), .data_in(data_in), .data_out(data_out)
    );

    // Clock generation
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Helper task for assertions
    task automatic assert_equal(logic [DATA_WIDTH-1:0] actual, logic [DATA_WIDTH-1:0] expected, string name);
        test_count++;
        if (actual === expected) begin
            pass_count++;
            $display("[PASS] Test %2d: %s | Expected: 0x%h, Got: 0x%h", test_count, name, expected, actual);
        end
        else begin
            fail_count++;
            $display("[FAIL] Test %2d: %s | Expected: 0x%h, Got: 0x%h", test_count, name, expected, actual);
            assert(0) else $error("Assertion failed: %s", name);
        end
    endtask

    initial begin
        $display("\nxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx");
        $display("x         Scratchpad Memory - Simple Self-Checking TB            x");
        $display("x              Testing write_done Flag & FSM Logic               x");
        $display("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx\n");

        // Initialize
        rst = 1'b0;
        cs = 1'b0;
        rw_ = 1'b0;
        wr_addr = '0;
        data_in = '0;
        #(2*CLK_PERIOD);

        // Release reset and select chip
        rst = 1'b1;
        cs = 1'b1;
        #(CLK_PERIOD);

        // ========== TEST 1: RESET -> READ should output 0 ==========
        $display("xxxx TEST 1: RESET -> READ (no prior write, should output 0) xxxx");
        rw_ = 1'b1;  // Read request
        wr_addr = 8'd0;
        #(CLK_PERIOD);
        #(CLK_PERIOD);  // Wait for latency
        assert_equal(data_out, 32'h00000000, "T1: RESET->READ outputs 0");
        $display("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx=\n");

        // ========== TEST 2: RESET -> WRITE -> READ ==========
        $display("xxxx TEST 2: Write 0xAAAAAAAA then Read (write_done should be 1) xxxx");
        rw_ = 1'b0;  // Write request
        wr_addr = 8'd5;
        data_in = 32'hAAAAAAAA;
        #(CLK_PERIOD);

        rw_ = 1'b1;  // Read request
        #(CLK_PERIOD);
        #(CLK_PERIOD);  // Wait for read latency
        assert_equal(data_out, 32'hAAAAAAAA, "T2: After WRITE, READ outputs valid data");
        $display("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx=\n");

        // ========== TEST 3: READ -> READ (after write, should output valid data) ==========
        $display("xxxx TEST 3: READ -> READ (back-to-back reads) xxxx");
        rw_ = 1'b1;  // Stay in READ
        wr_addr = 8'd5;
        #(CLK_PERIOD);
        #(CLK_PERIOD);  // Wait for read latency
        assert_equal(data_out, 32'hAAAAAAAA, "T3: READ->READ outputs same data");
        $display("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx=\n");

        // ========== TEST 4: WRITE to different address, then READ ==========
        $display("xxxx TEST 4: Write 0xBBBBBBBB to different addr, READ it xxxx");
        rw_ = 1'b0;  // Write
        wr_addr = 8'd10;
        data_in = 32'hBBBBBBBB;
        #(CLK_PERIOD);

        rw_ = 1'b1;  // Read from new address
        wr_addr = 8'd10;
        #(CLK_PERIOD);
        #(CLK_PERIOD);  // Wait for read latency
        assert_equal(data_out, 32'hBBBBBBBB, "T4: READ new address outputs correct data");
        $display("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx=\n");

        // ========== TEST 5: Multiple writes to same address ==========
        $display("xxxx TEST 5: Multiple writes to same address xxxx");
        rw_ = 1'b0;
        wr_addr = 8'd20;
        data_in = 32'h11111111;
        #(CLK_PERIOD);

        data_in = 32'h22222222;
        #(CLK_PERIOD);

        data_in = 32'h33333333;
        #(CLK_PERIOD);

        rw_ = 1'b1;  // Read to get last written value
        #(CLK_PERIOD);
        #(CLK_PERIOD);  // Wait for read latency
        assert_equal(data_out, 32'h33333333, "T5: Last written value is read correctly");
        $display("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx=\n");

        // ========== TEST 6: Chip select behavior ==========
        $display("xxxx TEST 6: Chip select (cs=0) forces output to 0 xxxx");
        cs = 1'b0;
        #(CLK_PERIOD);
        assert_equal(data_out, 32'h00000000, "T6: cs=0 forces data_out to 0");
        cs = 1'b1;
        #(CLK_PERIOD);
        $display("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx=\n");

        // ========== TEST 7: 2D memory addressing (tree mux test) ==========
        $display("xxxx TEST 7: 2D memory addressing (different addresses) xxxx");
        rw_ = 1'b0;
        wr_addr = 8'd0;
        data_in = 32'hDEADBEEF;
        #(CLK_PERIOD);

        wr_addr = 8'd15;
        data_in = 32'hCAFECAFE;
        #(CLK_PERIOD);

        rw_ = 1'b1;
        wr_addr = 8'd0;
        #(CLK_PERIOD);
        #(CLK_PERIOD);
        assert_equal(data_out, 32'hDEADBEEF, "T7a: Read addr 0 (2D mux test)");

        wr_addr = 8'd15;
        #(CLK_PERIOD);
        #(CLK_PERIOD);
        assert_equal(data_out, 32'hCAFECAFE, "T7b: Read addr 15 (2D mux test)");
        $display("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx=\n");

        // ========== TEST 8: Reset clears everything ==========
        $display("xxxx TEST 8: Reset behavior xxxx");
        rst = 1'b0;
        #(CLK_PERIOD);
        rst = 1'b1;
        #(CLK_PERIOD);

        // After reset, READ should output 0 (write_done should be 0)
        rw_ = 1'b1;
        wr_addr = 8'd0;
        #(CLK_PERIOD);
        #(CLK_PERIOD);
        assert_equal(data_out, 32'h00000000, "T8: After reset, READ outputs 0");
        $display("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx=\n");

        // ========== SUMMARY ==========
        #(2*CLK_PERIOD);
        $display("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx");
        $display("xxxx                      TEST SUMMARY                        xxxx");
        $display("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx");
        $display("xxxx       Total Tests:    %2d                                xxxx", test_count);
        $display("xxxx       Passed:         %2d                                xxxx", pass_count);
        $display("xxxx       Failed:         %2d                                xxxx", fail_count);
        $display("xxxx       Pass Rate:      %3d%%                              xxxx", (pass_count * 100) / test_count);
        $display("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx\n");

        if (fail_count == 0) begin
            $display("ALL TESTS PASSED! Design is correct.\n");
        end
        else begin
            $display("%0d TESTS FAILED! Review design.\n", fail_count);
        end



        $finish;
    end
        final begin
            $display("\nFinal summary:\n");
            $display("Total tests:      %d\n", test_count);
            $display("Passed     :      %d\n", pass_count);
            $display("Failed     :      %d\n", fail_count);
            $display("Pass rate  :      %d%%\n", (pass_count * 100) / test_count);
        end

endmodule
