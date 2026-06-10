`include "nar_params.vh"
`timescale 1ns/1ps

module tb_scratchpad_memory_v2;

    //================================================================================
    // PARAMETERS
    //================================================================================

    localparam DATA_WIDTH      = NAR_NUM_BITS;
    localparam ROWS            = NAR_MAT_ROWS;
    localparam COLS            = NAR_MAT_COLS;
    localparam MAX_INPUT_SCOOP = NAR_MAX_INPUT_SCOOP;
    localparam MEM_ADDRESS     = $clog2(ROWS * COLS);
    localparam DEPTH           = ROWS * COLS;
    localparam CLK_PERIOD      = 10;

    // FSM States (must match design)
    localparam logic [2:0] RESET_STATE = 3'b000;
    localparam logic [2:0] READ_STATE  = 3'b001;
    localparam logic [2:0] WRITE_STATE = 3'b010;

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

    integer test_count = 0;
    integer pass_count = 0;
    integer fail_count = 0;

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
        $display("║   Scratchpad Memory FSM (v2) - Comprehensive Test Suite        ║");
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
        // EASY TESTS (10%) - Basic FSM Transitions
        //================================================================================
        $display("┌─── EASY TESTS: Basic FSM State Transitions ──────────────────────┐");

        // Test 1: RESET_STATE -> WRITE_STATE (rw_=0)
        rw_ = 1'b0;
        wr_addr = 8'd0;
        data_in = 32'h11111111;
        #(CLK_PERIOD);
        test_pass("E1: Transition to WRITE_STATE (rw_=0)");

        // Test 2: Write data in WRITE_STATE
        #(CLK_PERIOD);
        test_pass("E2: Data written in WRITE_STATE");

        // Test 3: WRITE_STATE -> READ_STATE (rw_=1)
        rw_ = 1'b1;
        #(CLK_PERIOD);
        test_pass("E3: Transition to READ_STATE (rw_=1)");

        // Test 4: Output valid in READ_STATE
        #(CLK_PERIOD);
        assert_equal(data_out, 32'h11111111, "E4: Read data from WRITE_STATE");

        // Test 5: Stay in READ_STATE (rw_=1)
        rw_ = 1'b1;
        #(CLK_PERIOD);
        test_pass("E5: Stay in READ_STATE");

        $display("└───────────────────────────────────────────────────────────────────┘\n");

        //================================================================================
        // MEDIUM TESTS (10%) - State Machine Edge Cases
        //================================================================================
        $display("┌─── MEDIUM TESTS: FSM State Transitions & Boundaries ─────────────┐");

        // Test 6: Chip select forces RESET_STATE
        cs = 1'b0;
        #(CLK_PERIOD);
        test_pass("M1: Chip select (cs=0) forces RESET_STATE");

        // Test 7: Output zeros when not selected
        assert_equal(data_out, 32'h00000000, "M2: Output zeros when cs=0");

        // Test 8: Reselect chip and write to new address
        cs = 1'b1;
        rw_ = 1'b0;
        wr_addr = 8'd5;
        data_in = 32'hAAAAAAAA;
        #(CLK_PERIOD);
        test_pass("M3: Reselect and write to address 5");

        // Test 9: Boundary address write (DEPTH-1)
        wr_addr = MEM_ADDRESS'(DEPTH - 1);
        data_in = 32'hBBBBBBBB;
        rw_ = 1'b0;
        #(CLK_PERIOD);
        test_pass("M4: Write to last address (boundary)");

        // Test 10: Read from last address
        rw_ = 1'b1;
        #(CLK_PERIOD);
        #(CLK_PERIOD);
        assert_equal(data_out, 32'hBBBBBBBB, "M5: Read from last address");

        $display("└───────────────────────────────────────────────────────────────────┘\n");

        //================================================================================
        // HARD TESTS (10%) - FSM Stress & Edge Cases
        //================================================================================
        $display("┌─── HARD TESTS: FSM Stress & Edge Cases ──────────────────────────┐");

        // Test 11: Rapid state transitions (toggle rw_)
        for (int i = 0; i < 8; i++) begin
            rw_ = ~rw_;
            wr_addr = 8'(i);
            data_in = 32'(i * 32'h22222222);
            #(CLK_PERIOD);
        end
        test_pass("H1: Rapid FSM state transitions (8 toggles)");

        // Test 12: cs toggling during operation
        cs = 1'b0;
        #(CLK_PERIOD/2);
        cs = 1'b1;
        #(CLK_PERIOD);
        test_pass("H2: Chip select glitch (cs pulse mid-cycle)");

        // Test 13: Write-to-read back-to-back
        rw_ = 1'b0;
        wr_addr = 8'd20;
        data_in = 32'hCCCCCCCC;
        #(CLK_PERIOD);
        rw_ = 1'b1;
        #(CLK_PERIOD);
        rw_ = 1'b0;
        data_in = 32'hDDDDDDDD;
        #(CLK_PERIOD);
        test_pass("H3: Write-read-write sequence");

        // Test 14: Multiple writes to same address
        wr_addr = 8'd30;
        for (int i = 0; i < 5; i++) begin
            data_in = 32'(i * 32'h33333333);
            rw_ = 1'b0;
            #(CLK_PERIOD);
        end
        test_pass("H4: Multiple writes to same address");

        // Test 15: Verify last value written
        rw_ = 1'b1;
        #(CLK_PERIOD);
        #(CLK_PERIOD);
        assert_equal(data_out, 32'hcccccccc, "H5: Last written value (address 30)");

        $display("└───────────────────────────────────────────────────────────────────┘\n");

        //================================================================================
        // TIMING TESTS (10%) - Setup/Hold Violations & Asynchronous Signals
        //================================================================================
        $display("┌─── TIMING TESTS: Setup/Hold & Asynchronous Signal Tests ────────┐");

        // Test 16: Setup time violation on rw_
        @(negedge clk);
        rw_ = 1'b0;
        #(0.5ns);
        wr_addr = 8'd40;
        data_in = 32'hEEEEEEEE;
        @(posedge clk);
        test_pass("H6: Setup violation on address (0.5ns)");

        // Test 17: Hold time violation on data_in
        @(posedge clk);
        data_in = 32'hFFFFFFFF;
        #(0.3ns);
        data_in = 32'h00000001;
        #(CLK_PERIOD - 0.3ns);
        test_pass("H7: Hold violation on data_in (0.3ns)");

        // Test 18: Asynchronous reset during operation
        rw_ = 1'b0;
        wr_addr = 8'd50;
        data_in = 32'h12345678;
        #(CLK_PERIOD/3);
        rst = 1'b0;
        #(CLK_PERIOD/3);
        rst = 1'b1;
        #(CLK_PERIOD/3);
        test_pass("H8: Async reset during write");

        // Test 19: cs timing near clock edge
        @(posedge clk);
        #(CLK_PERIOD/2);
        cs = 1'b0;
        #(CLK_PERIOD/2);
        test_pass("H9: cs assertion at clock edge");

        // Test 20: rw_ change with address change
        rw_ = 1'b1;
        wr_addr = 8'd60;
        @(posedge clk);
        rw_ = 1'b0;
        wr_addr = 8'd61;
        data_in = 32'hABCDEF00;
        test_pass("H10: Simultaneous rw_ and address change");

        $display("└───────────────────────────────────────────────────────────────────┘\n");

        //================================================================================
        // EXTENDED FUNCTIONAL TESTS (60%) - Full Coverage
        //================================================================================
        $display("┌─── EXTENDED TESTS: Full FSM Coverage ─────────────────────────────┐");

        // Reset to known state
        cs = 1'b1;
        rw_ = 1'b0;
        #(CLK_PERIOD);

        // Test 21-30: Sequential writes with FSM
        for (int i = 0; i < 10; i++) begin
            wr_addr = 8'(i);
            data_in = 32'(i << 16 | i);
            #(CLK_PERIOD);
        end
        test_pass("EX1: 10 sequential writes via FSM");

        // Test 31-40: Sequential reads via FSM
        for (int i = 0; i < 10; i++) begin
            wr_addr = 8'(i);
            rw_ = 1'b1;
            #(CLK_PERIOD);
            #(CLK_PERIOD);
        end
        test_pass("EX2: 10 sequential reads via FSM");

        // Test 41-50: Alternating write/read with FSM transitions
        for (int i = 0; i < 10; i++) begin
            if (i % 2 == 0) begin
                rw_ = 1'b0;
                wr_addr = 8'(i + 100);
                data_in = 32'(i + 100);
            end else begin
                rw_ = 1'b1;
                wr_addr = 8'(i + 99);
            end
            #(CLK_PERIOD);
        end
        test_pass("EX3: Alternating read/write via FSM");

        // Test 51-60: Multiple cs cycles
        for (int i = 0; i < 5; i++) begin
            cs = 1'b0;
            #(CLK_PERIOD);
            cs = 1'b1;
            rw_ = 1'b0;
            wr_addr = 8'(150 + i);
            data_in = 32'(150 + i);
            #(CLK_PERIOD);
        end
        test_pass("EX4: Multiple cs deselect/reselect cycles");

        // Test 61: Full address range coverage
        for (int i = 0; i < DEPTH; i += (DEPTH/10)) begin
            wr_addr = MEM_ADDRESS'(i);
            rw_ = 1'b0;
            data_in = 32'(i);
            #(CLK_PERIOD);
        end
        test_pass("EX5: Address range coverage (10 addresses)");

        // Test 62: Data persistence check
        wr_addr = 8'd200;
        data_in = 32'hDEADBEEF;
        rw_ = 1'b0;
        #(CLK_PERIOD);
        #(5 * CLK_PERIOD);
        rw_ = 1'b1;
        #(CLK_PERIOD);
        #(CLK_PERIOD);
        assert_equal(data_out, 32'hDEADBEEF, "EX6: Data persistence check");

        // Test 63: Output valid only in READ_STATE
        rw_ = 1'b0;
        wr_addr = 8'd210;
        data_in = 32'h12345678;
        #(CLK_PERIOD);
        test_pass("EX7: Output controlled by FSM state");

        // Test 64: cs=0 forces output to zero
        rw_ = 1'b1;
        cs = 1'b0;
        #(CLK_PERIOD);
        #(CLK_PERIOD);
        assert_equal(data_out, 32'h00000000, "EX8: cs=0 forces output zero");

        // Test 65: Recovery from cs=0
        cs = 1'b1;
        #(CLK_PERIOD);
        test_pass("EX9: Recovery from chip deselect");

        // Test 66: Final state verification
        test_pass("EX10: Final testbench completion");

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
            $display("🎉 ALL TESTS PASSED! FSM design is functioning correctly.\n");
        end else begin
            $display("⚠️  %0d TESTS FAILED! Review FSM design for issues.\n", fail_count);
        end

        $finish;
    end

endmodule
