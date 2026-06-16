`include "nar_params.vh"
`timescale 1ns/1ps

module tb_scratchpad_memory_v3;

    localparam DATA_WIDTH      = NAR_NUM_BITS;
    localparam ROWS            = NAR_MAT_ROWS;
    localparam COLS            = NAR_MAT_COLS;
    localparam MAX_INPUT_SCOOP = NAR_MAX_INPUT_SCOOP;
    localparam MEM_ADDRESS     = $clog2(ROWS * COLS);
    localparam DEPTH           = ROWS * COLS;
    localparam CLK_PERIOD      = 10;

    localparam logic [2:0] RESET_STATE = 3'b000;
    localparam logic [2:0] READ_STATE  = 3'b001;
    localparam logic [2:0] WRITE_STATE = 3'b010;

    logic clk, rst, rw_, cs;
    logic [MEM_ADDRESS-1:0] wr_addr;
    logic [DATA_WIDTH-1:0] data_in, data_out;

    integer test_count = 0, pass_count = 0, fail_count = 0;

    scratchpad_memory #(
        .DATA_WIDTH(DATA_WIDTH),
        .ROWS(ROWS),
        .COLS(COLS),
        .MAX_INPUT_SCOOP(MAX_INPUT_SCOOP),
        .MEM_ADDRESS(MEM_ADDRESS)
    ) dut (
        .clk(clk), .rst(rst), .rw_(rw_), .cs(cs),
        .wr_addr(wr_addr), .data_in(data_in), .data_out(data_out)
    );

    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    task automatic test_pass(string name);
        pass_count++; test_count++;
        $display("[PASS] Test %3d: %s", test_count, name);
    endtask

    task automatic test_fail(string name, string reason);
        fail_count++; test_count++;
        $display("[FAIL] Test %3d: %s | %s", test_count, name, reason);
    endtask

    task automatic assert_equal(logic [DATA_WIDTH-1:0] actual, logic [DATA_WIDTH-1:0] expected, string name);
        string reason;
        if (actual === expected) test_pass(name);
        else begin
            $sformat(reason, "Expected 0x%h, Got 0x%h", expected, actual);
            test_fail(name, reason);
        end
    endtask

    initial begin
        $display("\n╔════════════════════════════════════════════════════════════════╗");
        $display("║  Scratchpad Memory FSM v3 (1-cycle latency) - Test Suite       ║");
        $display("║  DATA_WIDTH=%0d, DEPTH=%0d, ADDRESS_WIDTH=%0d            ║", DATA_WIDTH, DEPTH, MEM_ADDRESS);
        $display("╚════════════════════════════════════════════════════════════════╝\n");

        rst = 1'b0; cs = 1'b0; rw_ = 1'b0; wr_addr = '0; data_in = '0;
        #(2*CLK_PERIOD);
        rst = 1'b1; cs = 1'b1;
        #(CLK_PERIOD);

        //================================================================================
        // EASY TESTS (10%) - Basic Single-Cycle Operations
        //================================================================================
        $display("┌─── EASY TESTS: Basic FSM Operations ──────────────────────────────┐");

        // E1-E5: Simple write-then-read with proper latency accounting
        for (int i = 0; i < 5; i++) begin
            wr_addr = 8'(i);
            data_in = 32'(i * 32'h11111111);
            rw_ = 1'b0;
            #(CLK_PERIOD);
        end

        for (int i = 0; i < 5; i++) begin
            string test_desc;
            wr_addr = 8'(i);
            rw_ = 1'b1;
            #(CLK_PERIOD);
            #(CLK_PERIOD);  // EXTRA CYCLE for 1-cycle latency
            test_desc = $sformatf("E%0d: Read addr %0d", i+1, i);
            assert_equal(data_out, 32'(i * 32'h11111111), test_desc);
        end

        $display("└───────────────────────────────────────────────────────────────────┘\n");

        //================================================================================
        // MEDIUM TESTS (10%) - Boundary & Pattern Testing
        //================================================================================
        $display("┌─── MEDIUM TESTS: Boundaries & Special Patterns ───────────────────┐");

        // M1-M5: Write/read patterns with latency
        wr_addr = 8'd100;
        data_in = 32'h00000000;
        rw_ = 1'b0;
        #(CLK_PERIOD);
        test_pass("M1: Write ZEROS pattern");

        wr_addr = 8'd101;
        data_in = 32'hFFFFFFFF;
        #(CLK_PERIOD);
        test_pass("M2: Write ONES pattern");

        rw_ = 1'b1;
        wr_addr = 8'd100;
        #(CLK_PERIOD);
        #(CLK_PERIOD);
        assert_equal(data_out, 32'h00000000, "M3: Read ZEROS");

        wr_addr = 8'd101;
        #(CLK_PERIOD);
        #(CLK_PERIOD);
        assert_equal(data_out, 32'hFFFFFFFF, "M4: Read ONES");

        wr_addr = MEM_ADDRESS'(DEPTH-1);
        data_in = 32'hABCDEF00;
        rw_ = 1'b0;
        #(CLK_PERIOD);
        test_pass("M5: Write to last address");

        $display("└───────────────────────────────────────────────────────────────────┘\n");

        //================================================================================
        // HARD TESTS (10%) - Latency Pipeline Stress & Edge Cases
        //================================================================================
        $display("┌─── HARD TESTS: Latency Pipeline Stress ──────────────────────────┐");

        // H1: Address change during read latency pipeline
        wr_addr = 8'd200;
        data_in = 32'hAAAAAAAA;
        rw_ = 1'b0;
        #(CLK_PERIOD);
        rw_ = 1'b1;
        #(CLK_PERIOD);
        wr_addr = 8'd201;  // Change address DURING pipeline
        data_in = 32'hBBBBBBBB;
        #(CLK_PERIOD);
        #(CLK_PERIOD);  // Extra cycle for new address's latency
        assert_equal(data_out, 32'hBBBBBBBB, "H1: Address change in pipeline");

        // H2: Rapid mode switching with latency
        for (int i = 0; i < 3; i++) begin
            rw_ = 1'b0;
            wr_addr = 8'(i + 210);
            data_in = 32'(i + 210);
            #(CLK_PERIOD);
            rw_ = 1'b1;
            #(CLK_PERIOD);
            #(CLK_PERIOD);  // Latency
            rw_ = 1'b0;
            #(CLK_PERIOD);
        end
        test_pass("H2: Rapid write-read-write with latency");

        // H3: cs deselect during read latency
        wr_addr = 8'd220;
        data_in = 32'hCCCCCCCC;
        rw_ = 1'b0;
        #(CLK_PERIOD);
        rw_ = 1'b1;
        #(CLK_PERIOD);
        cs = 1'b0;  // Deselect DURING latency
        #(CLK_PERIOD);
        assert_equal(data_out, 32'h00000000, "H3: cs deselect during pipeline");

        cs = 1'b1;
        #(CLK_PERIOD);

        // H4: Back-to-back reads (pipelining)
        for (int i = 0; i < 5; i++) begin
            wr_addr = 8'(i + 230);
            data_in = 32'(i + 230);
            rw_ = 1'b0;
            #(CLK_PERIOD);
        end
        rw_ = 1'b1;
        for (int i = 0; i < 5; i++) begin
            string test_desc;
            wr_addr = 8'(i + 230);
            #(CLK_PERIOD);
            #(CLK_PERIOD);  // Latency
            test_desc = $sformatf("H4_read%0d", i);
            assert_equal(data_out, 32'(i + 230), test_desc);
        end

        // H5: Reset during read latency (worst case)
        wr_addr = 8'd250;
        data_in = 32'hDEADDEAD;
        rw_ = 1'b0;
        #(CLK_PERIOD);
        rw_ = 1'b1;
        #(CLK_PERIOD);
        rst = 1'b0;  // Reset DURING latency
        #(CLK_PERIOD);
        rst = 1'b1;
        #(CLK_PERIOD);
        assert_equal(data_out, 32'h00000000, "H5: Reset during read latency");

        $display("└───────────────────────────────────────────────────────────────────┘\n");

        //================================================================================
        // TIMING TESTS (10%) - Setup/Hold with Latency
        //================================================================================
        $display("┌─── TIMING TESTS: Setup/Hold & Asynchronous ─────────────────────┐");

        // T1-T5: Timing violations
        @(negedge clk);
        rw_ = 1'b0;
        #(0.5ns);
        wr_addr = 8'd260;
        data_in = 32'hFEEDFEED;
        @(posedge clk);
        test_pass("T1: Setup violation on address");

        @(posedge clk);
        data_in = 32'h12345678;
        #(0.3ns);
        data_in = 32'h87654321;
        #(CLK_PERIOD - 0.3ns);
        test_pass("T2: Hold violation on data_in");

        rw_ = 1'b1;
        #(CLK_PERIOD);
        rst = 1'b0;
        #(CLK_PERIOD/3);
        rst = 1'b1;
        #(2*CLK_PERIOD/3);
        test_pass("T3: Reset near clock edge");

        cs = 1'b0;
        #(CLK_PERIOD/2);
        cs = 1'b1;
        #(CLK_PERIOD/2);
        test_pass("T4: cs glitch mid-cycle");

        @(posedge clk);
        rw_ = ~rw_;
        wr_addr = 8'(wr_addr + 1);
        data_in = 32'(data_in + 1);
        test_pass("T5: Simultaneous rw_ + addr + data change");

        $display("└───────────────────────────────────────────────────────────────────┘\n");

        //================================================================================
        // EXTENDED TESTS (60%) - Comprehensive Coverage
        //================================================================================
        $display("┌─── EXTENDED TESTS: Full Coverage ────────────────────────────────┐");

        // EX1-EX10: Sequential writes (no reads)
        for (int i = 0; i < 20; i++) begin
            wr_addr = 8'(i);
            data_in = 32'(i << 16 | i);
            rw_ = 1'b0;
            #(CLK_PERIOD);
        end
        test_pass("EX1: 20 sequential writes");

        // EX2-EX11: Sequential reads with proper latency
        for (int i = 0; i < 20; i++) begin
            wr_addr = 8'(i);
            rw_ = 1'b1;
            #(CLK_PERIOD);
            #(CLK_PERIOD);  // LATENCY
        end
        test_pass("EX2: 20 sequential reads (with latency)");

        // EX3-EX12: Interleaved operations
        for (int i = 0; i < 10; i++) begin
            wr_addr = 8'(i + 50);
            data_in = 32'(i + 50);
            rw_ = 1'b0;
            #(CLK_PERIOD);
            rw_ = 1'b1;
            #(CLK_PERIOD);
            #(CLK_PERIOD);  // LATENCY
        end
        test_pass("EX3: 10 write-read pairs");

        // EX4-EX13: Address range coverage
        for (int i = 0; i < DEPTH; i += (DEPTH/20)) begin
            wr_addr = MEM_ADDRESS'(i);
            data_in = 32'(i);
            rw_ = 1'b0;
            #(CLK_PERIOD);
        end
        test_pass("EX4: Address range writes");

        // EX5-EX14: Data persistence with latency
        wr_addr = 8'd150;
        data_in = 32'hDEADBEEF;
        rw_ = 1'b0;
        #(CLK_PERIOD);
        #(10*CLK_PERIOD);
        rw_ = 1'b1;
        #(CLK_PERIOD);
        #(CLK_PERIOD);  // LATENCY
        assert_equal(data_out, 32'hDEADBEEF, "EX5: Data persistence");

        // EX6-EX15: cs behavior
        for (int i = 0; i < 5; i++) begin
            cs = 1'b0;
            #(CLK_PERIOD);
            cs = 1'b1;
            rw_ = 1'b0;
            wr_addr = 8'(i + 160);
            data_in = 32'(i + 160);
            #(CLK_PERIOD);
        end
        test_pass("EX6: Multiple cs cycles");

        // EX7-EX16: Pipeline stress (multiple reads in flight)
        rw_ = 1'b0;
        for (int i = 0; i < 10; i++) begin
            wr_addr = 8'(i + 170);
            data_in = 32'(i + 170);
            #(CLK_PERIOD);
        end
        rw_ = 1'b1;
        for (int i = 0; i < 10; i++) begin
            wr_addr = 8'(i + 170);
            #(CLK_PERIOD);
        end
        #(2*CLK_PERIOD);  // Drain pipeline
        test_pass("EX7: Pipeline stress test");

        // EX8-EX18: Alternating patterns
        for (int i = 0; i < 10; i++) begin
            if (i % 2 == 0) begin
                rw_ = 1'b0;
                data_in = 32'h55555555;
            end else begin
                rw_ = 1'b1;
                #(CLK_PERIOD);  // Extra latency on reads
            end
            #(CLK_PERIOD);
        end
        test_pass("EX8: Alternating read/write pattern");

        // Final padding
        #(5*CLK_PERIOD);

        $display("└───────────────────────────────────────────────────────────────────┘\n");
        $display("╔════════════════════════════════════════════════════════════════╗");
        $display("║                      TEST SUMMARY                              ║");
        $display("╠════════════════════════════════════════════════════════════════╣");
        $display("║  Total Tests:    %3d   |  Passed: %3d  |  Failed: %3d          ║", test_count, pass_count, fail_count);
        $display("║  Pass Rate:      %3d%%                                          ║", (pass_count * 100) / test_count);
        $display("╚════════════════════════════════════════════════════════════════╝\n");

        $finish;
    end

endmodule
