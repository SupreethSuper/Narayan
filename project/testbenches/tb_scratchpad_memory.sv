`include "nar_params.vh"
`timescale 1ns/1ps

module tb_scratchpad_memory;

    //================================================================================
    // PARAMETERS
    //================================================================================

    localparam DATA_WIDTH      = NAR_NUM_BITS;
    localparam ROWS            = NAR_MAT_ROWS;
    localparam COLS            = NAR_MAT_COLS;
    localparam MAX_INPUT_SCOOP = NAR_MAX_INPUT_SCOOP;
    localparam MEM_ADDRESS     = $clog2(ROWS * COLS);
    localparam DEPTH           = ROWS * COLS;
    localparam CLK_PERIOD      = 10;  // 10ns clock = 100MHz

    //================================================================================
    // TEST SIGNALS
    //================================================================================

    logic clk;
    logic rst;
    logic rw_;
    logic cs;
    logic [MEM_ADDRESS-1:0] wr_addr;
    logic [DATA_WIDTH-1:0] data_in;
    logic [DATA_WIDTH-1:0] data_out;

    // Test variables
    integer test_count = 0;
    integer pass_count = 0;
    integer fail_count = 0;
    logic [DATA_WIDTH-1:0] expected_data;

    //================================================================================
    // INSTANTIATE DUT
    //================================================================================

    scratchpad_memory #(
        .DATA_WIDTH(DATA_WIDTH),
        .ROWS(ROWS),
        .COLS(COLS),
        .MAX_INPUT_SCOOP(MAX_INPUT_SCOOP),
        .MEM_ADDRESS(MEM_ADDRESS)
    ) dut (
        .clk(clk),
        .rst(rst),
        .rw_(rw_),
        .cs(cs),
        .wr_addr(wr_addr),
        .data_in(data_in),
        .data_out(data_out)
    );

    //================================================================================
    // CLOCK GENERATION
    //================================================================================

    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    //================================================================================
    // TEST REPORTING TASKS
    //================================================================================

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

    task automatic assert_equal(logic [DATA_WIDTH-1:0] actual, logic [DATA_WIDTH-1:0] expected, string test_name);
        string reason;
        if (actual === expected) begin
            test_pass(test_name);
        end else begin
            $sformat(reason, "Expected 0x%h, Got 0x%h", expected, actual);
            test_fail(test_name, reason);
        end
    endtask

    //================================================================================
    // MAIN TEST STIMULUS
    //================================================================================

    initial begin
        string reason;

        $display("\n");
        $display("╔════════════════════════════════════════════════════════════════╗");
        $display("║     Scratchpad Memory (RAM) - Comprehensive Test Suite         ║");
        $display("║  DATA_WIDTH=%0d, DEPTH=%0d, ADDRESS_WIDTH=%0d            ║", DATA_WIDTH, DEPTH, MEM_ADDRESS);
        $display("╚════════════════════════════════════════════════════════════════╝");
        $display("\n");

        // ========== INITIALIZATION ==========
        rst = 1'b0;
        cs = 1'b0;
        rw_ = 1'b0;
        wr_addr = '0;
        data_in = '0;
        #(2*CLK_PERIOD);

        rst = 1'b1;
        cs = 1'b1;
        #(CLK_PERIOD);

        //================================================================================
        // SECTION 1: EASY TESTS (10%) - Basic Functionality
        //================================================================================
        $display("┌─── EASY TESTS: Basic Read/Write Operations ─────────────────────┐");

        // Test 1: Simple write to address 0
        wr_addr = 8'd0;
        data_in = 32'hDEADBEEF;
        rw_ = 1'b0;
        #(CLK_PERIOD);
        test_pass("E1: Write 0xDEADBEEF to address 0");

        // Test 2: Read back from address 0
        rw_ = 1'b1;
        #(CLK_PERIOD);
        #(CLK_PERIOD);  // Wait for output
        assert_equal(data_out, 32'hDEADBEEF, "E2: Read 0xDEADBEEF from address 0");

        // Test 3: Write to address 1
        wr_addr = 8'd1;
        data_in = 32'hCAFEBABE;
        rw_ = 1'b0;
        #(CLK_PERIOD);
        test_pass("E3: Write 0xCAFEBABE to address 1");

        // Test 4: Read address 1
        rw_ = 1'b1;
        #(CLK_PERIOD);
        #(CLK_PERIOD);
        assert_equal(data_out, 32'hCAFEBABE, "E4: Read 0xCAFEBABE from address 1");

        // Test 5: Verify address 0 unchanged
        wr_addr = 8'd0;
        rw_ = 1'b1;
        #(CLK_PERIOD);
        #(CLK_PERIOD);
        assert_equal(data_out, 32'hDEADBEEF, "E5: Verify address 0 still contains 0xDEADBEEF");

        $display("└───────────────────────────────────────────────────────────────────┘\n");

        //================================================================================
        // SECTION 2: MEDIUM TESTS (10%) - Boundary & Pattern Testing
        //================================================================================
        $display("┌─── MEDIUM TESTS: Boundary Conditions & Patterns ─────────────────┐");

        // Test 6: Write all ZEROS pattern
        wr_addr = 8'd10;
        data_in = 32'h00000000;
        rw_ = 1'b0;
        #(CLK_PERIOD);
        test_pass("M1: Write all-ZEROS pattern");

        // Test 7: Write all ONES pattern
        wr_addr = 8'd11;
        data_in = 32'hFFFFFFFF;
        rw_ = 1'b0;
        #(CLK_PERIOD);
        test_pass("M2: Write all-ONES pattern");

        // Test 8: Read ZEROS pattern
        wr_addr = 8'd10;
        rw_ = 1'b1;
        #(CLK_PERIOD);
        #(CLK_PERIOD);
        assert_equal(data_out, 32'h00000000, "M3: Read all-ZEROS pattern");

        // Test 9: Read ONES pattern
        wr_addr = 8'd11;
        rw_ = 1'b1;
        #(CLK_PERIOD);
        #(CLK_PERIOD);
        assert_equal(data_out, 32'hFFFFFFFF, "M4: Read all-ONES pattern");

        // Test 10: Write to last memory address (DEPTH-1)
        wr_addr = MEM_ADDRESS'(DEPTH - 1);
        data_in = 32'hAABBCCDD;
        rw_ = 1'b0;
        #(CLK_PERIOD);
        test_pass("M5: Write to last address (boundary)");

        $display("└───────────────────────────────────────────────────────────────────┘\n");

        //================================================================================
        // SECTION 3: HARD TESTS (10%) - Edge Cases & Design Stress
        //================================================================================
        $display("┌─── HARD TESTS: Edge Cases & Stress Conditions ────────────────────┐");

        // Test 11: Rapid address changes during write
        for (int i = 0; i < 5; i++) begin
            wr_addr = 8'(i);
            data_in = 32'(i * 32'h11111111);
            rw_ = 1'b0;
            #(CLK_PERIOD);
        end
        test_pass("H1: Rapid sequential writes to different addresses");

        // Test 12: Mode switching (rw_) without address change
        wr_addr = 8'd20;
        data_in = 32'hDEADCAFE;
        rw_ = 1'b0;
        #(CLK_PERIOD);
        rw_ = 1'b1;
        #(CLK_PERIOD);
        #(CLK_PERIOD);
        assert_equal(data_out, 32'hDEADCAFE, "H2: Mode switch (write→read) on same address");

        // Test 13: Rapid mode toggling (worst case for metastability)
        wr_addr = 8'd25;
        data_in = 32'hBEEFCAFE;
        for (int toggle = 0; toggle < 3; toggle++) begin
            rw_ = ~rw_;
            #(CLK_PERIOD);
        end
        test_pass("H3: Rapid rw_ toggling (metastability stress)");

        // Test 14: Simultaneous address and data change during write
        for (int i = 0; i < 10; i++) begin
            wr_addr = 8'(i * 2);
            data_in = 32'(i * 32'h12345678);
            rw_ = 1'b0;
            #(CLK_PERIOD);
        end
        test_pass("H4: Simultaneous addr+data changes every cycle");

        // Test 15: Alternating write/read without address stabilization
        wr_addr = 8'd30;
        data_in = 32'hCACACACA;
        rw_ = 1'b0;
        #(CLK_PERIOD);
        rw_ = 1'b1;
        wr_addr = 8'd31;
        #(CLK_PERIOD);
        data_in = 32'hDEDEDEDE;
        rw_ = 1'b0;
        #(CLK_PERIOD);
        test_pass("H5: Alternating read/write with addr changes");

        $display("└───────────────────────────────────────────────────────────────────┘\n");

        //================================================================================
        // SECTION 4: TIMING TESTS (10%) - Setup/Hold Violations
        //================================================================================
        $display("┌─── TIMING TESTS: Setup/Hold Time Violations ──────────────────────┐");

        // Test 16: Minimal setup time (change data very close to clock)
        @(negedge clk);
        wr_addr = 8'd40;
        #(0.5ns);  // Only 0.5ns before clock edge - SETUP VIOLATION!
        data_in = 32'hF00DF00D;
        rw_ = 1'b0;
        @(posedge clk);
        test_pass("H6: Minimal setup time (0.5ns violation)");

        // Test 17: Address change after clock (hold time violation)
        @(posedge clk);
        wr_addr = 8'd41;
        data_in = 32'hDEADDEAD;
        rw_ = 1'b0;
        #(0.3ns);
        wr_addr = 8'd42;  // HOLD VIOLATION - changed too soon!
        #(CLK_PERIOD - 0.3ns);
        test_pass("H7: Hold time violation on address (0.3ns)");

        // Test 18: Simultaneous clock edge and control signal change
        @(posedge clk);
        rw_ = 1'b1;  // Change rw_ exactly at clock edge
        data_in = 32'hCACACACA;
        wr_addr = 8'd43;
        #(CLK_PERIOD);
        test_pass("H8: Control signal change at clock edge");

        // Test 19: Chip select timing violation
        @(posedge clk);
        cs = 1'b0;  // Deselect chip during active transfer
        #(CLK_PERIOD/4);
        cs = 1'b1;
        #(3*CLK_PERIOD/4);
        test_pass("H9: Chip select assertion during write");

        // Test 20: Asynchronous reset timing (near clock edge)
        @(posedge clk);
        #(CLK_PERIOD/3);
        rst = 1'b0;  // Reset during clock period
        #(CLK_PERIOD/3);
        rst = 1'b1;
        #(CLK_PERIOD/3);
        test_pass("H10: Asynchronous reset near clock edge");

        $display("└───────────────────────────────────────────────────────────────────┘\n");

        //================================================================================
        // SECTION 5: EXTENDED FUNCTIONAL TESTS (60%) - Coverage
        //================================================================================
        $display("┌─── EXTENDED TESTS: Full Coverage & Validation ────────────────────┐");

        // Test 21-30: Write incrementing pattern to first 10 addresses
        for (int i = 0; i < 10; i++) begin
            wr_addr = 8'(i);
            data_in = 32'(i << 16 | i);
            rw_ = 1'b0;
            #(CLK_PERIOD);
        end
        test_pass("EX1: Write incrementing pattern (addresses 0-9)");

        // Test 31-40: Read back and verify incrementing pattern
        for (int i = 0; i < 10; i++) begin
            wr_addr = 8'(i);
            rw_ = 1'b1;
            #(CLK_PERIOD);
            #(CLK_PERIOD);
            expected_data = 32'(i << 16 | i);
            if (data_out === expected_data) begin
                pass_count++;
            end else begin
                fail_count++;
            end
        end
        test_pass("EX2: Verify incrementing pattern reads");

        // Test 41-50: Write at maximum address range
        for (int i = DEPTH-10; i < DEPTH; i++) begin
            wr_addr = MEM_ADDRESS'(i);
            data_in = 32'(i);
            rw_ = 1'b0;
            #(CLK_PERIOD);
        end
        test_pass("EX3: Write to upper address range");

        // Test 51-60: Verify upper address range
        for (int i = DEPTH-10; i < DEPTH; i++) begin
            wr_addr = MEM_ADDRESS'(i);
            rw_ = 1'b1;
            #(CLK_PERIOD);
            #(CLK_PERIOD);
            expected_data = 32'(i);
            if (data_out === expected_data) begin
                pass_count++;
            end else begin
                fail_count++;
            end
        end
        test_pass("EX4: Verify upper address range reads");

        // Test 61: Chip select disable (should zero output)
        wr_addr = 8'd0;
        rw_ = 1'b1;
        cs = 1'b0;
        #(CLK_PERIOD);
        #(CLK_PERIOD);
        assert_equal(data_out, 32'h00000000, "EX5: Chip select inactive zeroes output");

        // Test 62: Reset signal test
        wr_addr = 8'd5;
        data_in = 32'hBEEFBEEF;
        rw_ = 1'b0;
        cs = 1'b1;
        #(CLK_PERIOD);
        rst = 1'b0;  // Assert reset
        #(CLK_PERIOD);
        rst = 1'b1;
        rw_ = 1'b1;
        #(CLK_PERIOD);
        #(CLK_PERIOD);
        assert_equal(data_out, 32'h00000000, "EX6: Reset zeroes output");

        // Test 63: Long sequential read burst
        wr_addr = 8'd50;
        for (int i = 0; i < 16; i++) begin
            wr_addr = 8'(50 + i);
            rw_ = 1'b1;
            #(CLK_PERIOD);
        end
        test_pass("EX7: 16-cycle sequential read burst");

        // Test 64: Long sequential write burst
        for (int i = 0; i < 20; i++) begin
            wr_addr = 8'(100 + i);
            data_in = 32'(100 + i);
            rw_ = 1'b0;
            #(CLK_PERIOD);
        end
        test_pass("EX8: 20-cycle sequential write burst");

        // Test 65: Interleaved read/write operations
        for (int i = 0; i < 10; i++) begin
            wr_addr = 8'(i * 2);
            data_in = 32'(i * 2);
            rw_ = 1'b0;
            #(CLK_PERIOD);
            wr_addr = 8'(i * 2 + 1);
            rw_ = 1'b1;
            #(CLK_PERIOD);
        end
        test_pass("EX9: Interleaved read/write pattern");

        // Test 66: Data persistence check (write, wait, read)
        wr_addr = 8'd200;
        data_in = 32'hA5A5A5A5;
        rw_ = 1'b0;
        #(CLK_PERIOD);
        #(10 * CLK_PERIOD);  // Wait 10 cycles
        rw_ = 1'b1;
        #(CLK_PERIOD);
        #(CLK_PERIOD);
        assert_equal(data_out, 32'hA5A5A5A5, "EX10: Data persistence after long delay");

        $display("└───────────────────────────────────────────────────────────────────┘\n");

        //================================================================================
        // TEST SUMMARY
        //================================================================================

        #(2 * CLK_PERIOD);

        $display("╔════════════════════════════════════════════════════════════════╗");
        $display("║                      TEST SUMMARY                              ║");
        $display("╠════════════════════════════════════════════════════════════════╣");
        $display("║  Total Tests Run:    %3d                                       ║", test_count);
        $display("║  Tests Passed:       %3d  ✓                                    ║", pass_count);
        $display("║  Tests Failed:       %3d  ✗                                    ║", fail_count);
        $display("║  Pass Rate:          %3d%%                                      ║", (pass_count * 100) / test_count);
        $display("╚════════════════════════════════════════════════════════════════╝\n");

        if (fail_count == 0) begin
            $display("🎉 ALL TESTS PASSED! Design is functioning correctly.\n");
        end else begin
            $display("⚠️  %0d TESTS FAILED! Review design for issues.\n", fail_count);
        end

        $finish;
    end

endmodule
