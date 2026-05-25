`include "nar_params.vh"

module scratchpad_tb;

    // Parameters
    localparam DATA_WIDTH = NAR_NUM_BITS;
    localparam ROWS = NAR_MAT_ROWS;
    localparam COLS = NAR_MAT_COLS;
    localparam CLK_PERIOD = 10;  // 10ns clock period

    // Testbench signals
    logic clk;
    logic rst;
    logic [DATA_WIDTH-1:0] red;
    logic [DATA_WIDTH-1:0] green;
    logic [DATA_WIDTH-1:0] blue;
    logic [DATA_WIDTH-1:0] red_out   [0:ROWS-1][0:COLS-1];
    logic [DATA_WIDTH-1:0] green_out [0:ROWS-1][0:COLS-1];
    logic [DATA_WIDTH-1:0] blue_out  [0:ROWS-1][0:COLS-1];

    // Instantiate the DUT (Device Under Test)
    scratchpad #(
        .DATA_WIDTH(DATA_WIDTH),
        .ROWS(ROWS),
        .COLS(COLS)
    ) dut (
        .clk(clk),
        .rst(rst),
        .red(red),
        .green(green),
        .blue(blue),
        .red_out(red_out),
        .green_out(green_out),
        .blue_out(blue_out)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Helper task to verify all matrix elements match expected value
    task automatic verify_matrix(
        logic [DATA_WIDTH-1:0] expected_red,
        logic [DATA_WIDTH-1:0] expected_green,
        logic [DATA_WIDTH-1:0] expected_blue,
        string test_name
    );
        int errors = 0;
        begin
            for (int i = 0; i < ROWS; i++) begin
                for (int j = 0; j < COLS; j++) begin
                    if (red_out[i][j] !== expected_red) begin
                        $display("ERROR [%s] red_out[%0d][%0d] = %h, expected %h",
                                 test_name, i, j, red_out[i][j], expected_red);
                        errors++;
                    end
                    if (green_out[i][j] !== expected_green) begin
                        $display("ERROR [%s] green_out[%0d][%0d] = %h, expected %h",
                                 test_name, i, j, green_out[i][j], expected_green);
                        errors++;
                    end
                    if (blue_out[i][j] !== expected_blue) begin
                        $display("ERROR [%s] blue_out[%0d][%0d] = %h, expected %h",
                                 test_name, i, j, blue_out[i][j], expected_blue);
                        errors++;
                    end
                end
            end
            if (errors == 0) begin
                $display("✓ PASS [%s]: All matrix elements correct (R=%h, G=%h, B=%h)",
                         test_name, expected_red, expected_green, expected_blue);
            end else begin
                $display("✗ FAIL [%s]: %0d errors found", test_name, errors);
            end
        end
    endtask

    // Test stimulus
    initial begin
        $display("\n========================================");
        $display("  Scratchpad Module Testbench");
        $display("  DATA_WIDTH = %0d bits", DATA_WIDTH);
        $display("  MATRIX SIZE = %0d rows x %0d cols", ROWS, COLS);
        $display("  Total elements per channel = %0d", ROWS*COLS);
        $display("========================================\n");

        // Test 1: Initial reset behavior
        $display("[TEST 1] Reset Behavior");
        rst = 0;
        red = 8'h00;
        green = 8'h00;
        blue = 8'h00;
        #(CLK_PERIOD);
        verify_matrix(8'h00, 8'h00, 8'h00, "Reset");

        // Release reset
        rst = 1;
        #(CLK_PERIOD);

        // Test 2: Write single set of values
        $display("\n[TEST 2] Single Write - Values: R=AA, G=55, B=FF");
        red = 8'hAA;
        green = 8'h55;
        blue = 8'hFF;
        #(CLK_PERIOD);  // Wait for first propagation
        verify_matrix(8'hAA, 8'h55, 8'hFF, "Single Write");

        // Test 3: Multiple sequential writes
        $display("\n[TEST 3] Sequential Writes");
        for (int i = 1; i <= 4; i++) begin
            red = 8'h10 * i;
            green = 8'h20 * i;
            blue = 8'h30 * i;
            #(CLK_PERIOD);
            $display("Cycle %0d: Input R=%h G=%h B=%h", i, red, green, blue);
            verify_matrix(8'h10*i, 8'h20*i, 8'h30*i, $sformatf("Seq Write %0d", i));
        end

        // Test 4: Maximum values
        $display("\n[TEST 4] Maximum Values (All bits set)");
        red = {DATA_WIDTH{1'b1}};
        green = {DATA_WIDTH{1'b1}};
        blue = {DATA_WIDTH{1'b1}};
        #(CLK_PERIOD);
        verify_matrix({DATA_WIDTH{1'b1}}, {DATA_WIDTH{1'b1}}, {DATA_WIDTH{1'b1}}, "Max Values");

        // Test 5: Minimum values
        $display("\n[TEST 5] Minimum Values (All bits clear)");
        red = 8'h00;
        green = 8'h00;
        blue = 8'h00;
        #(CLK_PERIOD);
        verify_matrix(8'h00, 8'h00, 8'h00, "Min Values");

        // Test 6: Reset during operation
        $display("\n[TEST 6] Reset During Operation");
        red = 8'h12;
        green = 8'h34;
        blue = 8'h56;
        #(CLK_PERIOD);
        $display("Before reset: R=%h G=%h B=%h (written to matrix)", red, green, blue);

        rst = 0;  // Assert reset
        #(CLK_PERIOD);
        $display("After reset asserted:");
        verify_matrix(8'h00, 8'h00, 8'h00, "Reset During Op");

        rst = 1;  // Release reset
        #(CLK_PERIOD);

        // Test 7: Color gradient pattern
        $display("\n[TEST 7] Color Gradient Pattern");
        for (int i = 0; i < 8; i++) begin
            red = 8'h00 + (i * 8'h20);
            green = 8'h40 + (i * 8'h10);
            blue = 8'h80 + (i * 8'h08);
            #(CLK_PERIOD);
            verify_matrix(
                8'h00 + (i * 8'h20),
                8'h40 + (i * 8'h10),
                8'h80 + (i * 8'h08),
                $sformatf("Gradient %0d", i)
            );
        end

        // Test 8: Alternating pattern (checkerboard of values)
        $display("\n[TEST 8] Alternating Values");
        red = 8'hCC;
        green = 8'h33;
        blue = 8'hCC;
        #(CLK_PERIOD);
        verify_matrix(8'hCC, 8'h33, 8'hCC, "Alternating");

        // Final summary
        $display("\n========================================");
        $display("  Testbench Complete");
        $display("========================================\n");

        $finish;
    end

endmodule