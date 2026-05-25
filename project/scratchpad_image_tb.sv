`include "nar_params.vh"

module scratchpad_image_tb;

    // Parameters
    localparam DATA_WIDTH = NAR_NUM_BITS;
    localparam ROWS = NAR_MAT_ROWS;
    localparam COLS = NAR_MAT_COLS;
    localparam CLK_PERIOD = 10;
    localparam PROOF_OF_CONCEPT_PIXELS = 10000;  // Limit to 10k cycles for PoC

    // Include generated test vectors (from image_hex_converter.py)
    // This defines: IMG_WIDTH, IMG_HEIGHT, TOTAL_PIXELS, test_red[], test_green[], test_blue[]
    `include "vectors.sv"

    // Testbench signals
    logic clk;
    logic rst;
    logic [DATA_WIDTH-1:0] red;
    logic [DATA_WIDTH-1:0] green;
    logic [DATA_WIDTH-1:0] blue;
    logic [DATA_WIDTH-1:0] red_out   [0:ROWS-1][0:COLS-1];
    logic [DATA_WIDTH-1:0] green_out [0:ROWS-1][0:COLS-1];
    logic [DATA_WIDTH-1:0] blue_out  [0:ROWS-1][0:COLS-1];

    // Output file handles
    integer output_file;

    // Instantiate the DUT
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

    // Task to write output matrix to file
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
        $display("  Scratchpad Image Processing Testbench");
        $display("  Data Width: %0d bits", DATA_WIDTH);
        $display("  Hardware Matrix Size: %0d x %0d", ROWS, COLS);
        $display("  Image Size: %0d x %0d (%0d total pixels)", IMG_WIDTH, IMG_HEIGHT, TOTAL_PIXELS);
        $display("========================================\n");

        // Initialize
        rst = 0;
        red = 0;
        green = 0;
        blue = 0;
        #(2*CLK_PERIOD);

        // Release reset
        rst = 1;
        #(CLK_PERIOD);

        // Main test: Stream image pixels from generated vectors.sv (PROOF OF CONCEPT)
        $display("[TEST] Streaming image pixels into scratchpad (PROOF OF CONCEPT)\n");
        $display("[STEP 1] Loading %0d test vectors from vectors.sv (total available: %0d)...",
                 PROOF_OF_CONCEPT_PIXELS, TOTAL_PIXELS);

        // Stream first N pixels from the included test vectors (limited for PoC)
        for (int i = 0; i < PROOF_OF_CONCEPT_PIXELS; i++) begin
            red = test_red[i];
            green = test_green[i];
            blue = test_blue[i];
            #(CLK_PERIOD);

            // Progress indicator every 2500 pixels
            if ((i + 1) % 2500 == 0) begin
                $display("[INFO] Streamed %0d pixels...", i + 1);
            end
        end

        $display("[INFO] Completed streaming %0d test vectors (proof of concept)\n", PROOF_OF_CONCEPT_PIXELS);

        // Wait for final values to stabilize
        $display("[STEP 2] Waiting for outputs to stabilize...");
        #(CLK_PERIOD * 10);

        // Capture output matrix
        $display("[STEP 3] Capturing output matrix...");
        write_output_matrix("output_rgb.csv");

        // Optional: Run an alternate test with hardcoded gradient for debugging
        $display("\n[TEST 2] Alternative: Simple gradient pattern (for debugging)\n");

        // Reset the scratchpad
        $display("[STEP 4] Resetting scratchpad for secondary test...");
        rst = 0;
        #(CLK_PERIOD);
        rst = 1;
        #(CLK_PERIOD);

        // Generate a simple gradient (proof of concept: 10k pixels)
        $display("[STEP 5] Streaming gradient pattern (%0d pixels for PoC)...", PROOF_OF_CONCEPT_PIXELS);
        for (int i = 0; i < PROOF_OF_CONCEPT_PIXELS; i++) begin
            // Simple gradient: R increases, G steady, B decreases
            red = 8'h00 + ((i * 8'hFF) / PROOF_OF_CONCEPT_PIXELS);
            green = 8'h80;
            blue = 8'hFF - ((i * 8'hFF) / PROOF_OF_CONCEPT_PIXELS);
            #(CLK_PERIOD);

            if ((i + 1) % 2500 == 0) begin
                $display("[INFO] Gradient: Processed %0d pixels...", i + 1);
            end
        end

        // Wait for stabilization
        $display("\n[STEP 6] Waiting for gradient outputs to stabilize...");
        #(CLK_PERIOD * 10);

        // Capture the gradient test output
        $display("\n[STEP 7] Capturing gradient output matrix...");
        write_output_matrix("output_gradient.csv");

        $display("\n========================================");
        $display("  Testbench Complete (Proof of Concept)");
        $display("  Simulated: %0d clock cycles", PROOF_OF_CONCEPT_PIXELS * 2);
        $display("  Generated output files:");
        $display("    - output_rgb.csv (from first %0d vectors)", PROOF_OF_CONCEPT_PIXELS);
        $display("    - output_gradient.csv (from gradient pattern)");
        $display("  Note: Full simulation would require %0d cycles", TOTAL_PIXELS * 2);
        $display("========================================\n");

        $finish;
    end

endmodule
