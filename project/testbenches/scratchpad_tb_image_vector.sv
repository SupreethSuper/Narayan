`include "nar_params.vh"

module scratchpad_tb_image_vector;

    // Parameters from nar_params.vh
    localparam DATA_WIDTH = NAR_NUM_BITS;
    localparam ROWS = NAR_MAT_ROWS;
    localparam COLS = NAR_MAT_COLS;
    localparam CLK_PERIOD = 10;
    localparam MAX_INPUT_SCOOP = NAR_MAX_INPUT_SCOOP;

    // Include generated test vectors
    `include "vectors.sv"

    // Testbench signals
    logic clk;
    logic rst;

    // Single pixel input (NOT parallel) - simplified test
    logic [DATA_WIDTH-1:0] red_in;
    logic [DATA_WIDTH-1:0] green_in;
    logic [DATA_WIDTH-1:0] blue_in;

    logic [DATA_WIDTH-1:0] red_out   [0:ROWS-1][0:COLS-1];
    logic [DATA_WIDTH-1:0] green_out [0:ROWS-1][0:COLS-1];
    logic [DATA_WIDTH-1:0] blue_out  [0:ROWS-1][0:COLS-1];

    // File handles
    integer output_file;
    integer i, row, col;

    // Simplified scratchpad - broadcast to all positions
    // (This is the current hardware behavior)
    logic [DATA_WIDTH-1:0] red_pad   [0:ROWS-1][0:COLS-1];
    logic [DATA_WIDTH-1:0] green_pad [0:ROWS-1][0:COLS-1];
    logic [DATA_WIDTH-1:0] blue_pad  [0:ROWS-1][0:COLS-1];

    assign red_out   = red_pad;
    assign green_out = green_pad;
    assign blue_out  = blue_pad;

    initial begin
        red_pad   <= '{default:0};
        green_pad <= '{default:0};
        blue_pad  <= '{default:0};
    end

    // Simple broadcast logic (single input)
    always_ff @(posedge clk or negedge rst)
    begin
        if(~rst)
        begin
            for (int i = 0; i < ROWS; i++)
                for (int j = 0; j < COLS; j++)
                begin
                    red_pad[i][j]   <= 0;
                    green_pad[i][j] <= 0;
                    blue_pad[i][j]  <= 0;
                end
        end
        else
        begin
            // Broadcast single input to all positions
            for (int i = 0; i < ROWS; i++)
            begin
                for (int j = 0; j < COLS; j++)
                begin
                    red_pad[i][j]   <= red_in;
                    green_pad[i][j] <= green_in;
                    blue_pad[i][j]  <= blue_in;
                end
            end
        end
    end

    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Task to write output matrix to CSV
    task write_output_matrix(string filename);
        integer row, col;
        begin
            output_file = $fopen(filename, "w");
            if (output_file == 0) begin
                $display("[ERROR] Could not open output file: %s", filename);
            end else begin
                // Write header
                $fwrite(output_file, "row,col,red,green,blue\n");

                // Write all pixels
                for (row = 0; row < ROWS; row++) begin
                    for (col = 0; col < COLS; col++) begin
                        $fwrite(output_file, "%0d,%0d,%0h,%0h,%0h\n",
                                row, col,
                                red_out[row][col],
                                green_out[row][col],
                                blue_out[row][col]);
                    end
                end

                $fclose(output_file);
                $display("[INFO] Output written to: %s", filename);
            end
        end
    endtask

    // Main test stimulus
    initial begin
        $display("\n========================================");
        $display("  DIRECT VECTOR TEST (Single Input)");
        $display("  Data Width: %0d bits", DATA_WIDTH);
        $display("  Matrix Size: %0d x %0d", ROWS, COLS);
        $display("  Total Pixels: %0d", TOTAL_PIXELS);
        $display("========================================\n");

        // Initialize
        rst = 0;
        red_in = 0;
        green_in = 0;
        blue_in = 0;
        #(2*CLK_PERIOD);

        // Release reset
        rst = 1;
        #(CLK_PERIOD);

        // Test: Stream vectors.sv values DIRECTLY (red→red, green→green, blue→blue)
        $display("[TEST] Streaming test_red → red, test_green → green, test_blue → blue\n");
        $display("[STEP 1] Loading all %0d test vectors from vectors.sv...", TOTAL_PIXELS);

        // Stream ALL pixels with 1 pixel per cycle (simplest case)
        for (int i = 0; i < TOTAL_PIXELS; i++) begin
            red_in = test_red[i];
            green_in = test_green[i];
            blue_in = test_blue[i];
            #(CLK_PERIOD);

            // Progress indicator every 50000 pixels
            if ((i + 1) % 50000 == 0) begin
                $display("[INFO] Streamed %0d pixels...", i + 1);
            end
        end

        $display("[INFO] Completed streaming all %0d pixels\n", TOTAL_PIXELS);

        // Wait for final values to stabilize
        $display("[STEP 2] Waiting for outputs to stabilize...");
        #(CLK_PERIOD * 10);

        // Capture output matrix
        $display("[STEP 3] Capturing output matrix to vector_output.csv...");
        write_output_matrix("vector_output.csv");

        $display("\n========================================");
        $display("  Test Complete");
        $display("  Files generated:");
        $display("    - vector_output.csv (from direct vector streaming)");
        $display("\n  Expected behavior:");
        $display("    - All 500x500 positions should show the LAST pixel value");
        $display("    - red = test_red[249999]");
        $display("    - green = test_green[249999]");
        $display("    - blue = test_blue[249999]");
        $display("========================================\n");

        $finish;
    end

endmodule
