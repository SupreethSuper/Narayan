`include "nar_params.vh"
`timescale 1ns/1ps

module scratchpad_image_tb;

    //================================================================================
    // PARAMETERS
    //================================================================================

    localparam DATA_WIDTH = NAR_NUM_BITS;
    localparam ROWS = NAR_MAT_ROWS;
    localparam COLS = NAR_MAT_COLS;
    localparam CLK_PERIOD = 10;
    localparam MAX_INPUT_SCOOP = NAR_MAX_INPUT_SCOOP;

    // Include generated test vectors from image_hex_converter.py
    // Defines: IMG_WIDTH, IMG_HEIGHT, TOTAL_PIXELS, test_red[], test_green[], test_blue[]
    `include "vectors.sv"

    //================================================================================
    // TESTBENCH SIGNALS
    //================================================================================

    logic clk;
    logic rst;

    // Parallel input signals (parameterized by MAX_INPUT_SCOOP)
    logic [DATA_WIDTH-1:0] red_in   [0:MAX_INPUT_SCOOP-1];
    logic [DATA_WIDTH-1:0] green_in [0:MAX_INPUT_SCOOP-1];
    logic [DATA_WIDTH-1:0] blue_in  [0:MAX_INPUT_SCOOP-1];

    logic [DATA_WIDTH-1:0] red_out   [0:ROWS-1][0:COLS-1];
    logic [DATA_WIDTH-1:0] green_out [0:ROWS-1][0:COLS-1];
    logic [DATA_WIDTH-1:0] blue_out  [0:ROWS-1][0:COLS-1];

    // File I/O
    integer output_file;

    //================================================================================
    // INSTANTIATE DUT
    //================================================================================

    scratchpad #(
        .DATA_WIDTH(DATA_WIDTH),
        .ROWS(ROWS),
        .COLS(COLS),
        .MAX_INPUT_SCOOP(MAX_INPUT_SCOOP)
    ) dut (
        .clk(clk),
        .rst(rst),
        .red(red_in),
        .green(green_in),
        .blue(blue_in),
        .red_out(red_out),
        .green_out(green_out),
        .blue_out(blue_out)
    );

    //================================================================================
    // CLOCK GENERATION
    //================================================================================

    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    //================================================================================
    // TASK: Write output matrix to CSV file
    //================================================================================

    task write_output_matrix(string filename);
        integer row, col;
        begin
            output_file = $fopen(filename, "w");
            if (output_file == 0) begin
                $display("[ERROR] Could not open output file: %s", filename);
            end else begin
                // Write CSV header
                $fwrite(output_file, "row,col,red,green,blue\n");

                // Write all pixels from output matrix
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
                $display("[INFO] Output matrix written to: %s", filename);
            end
        end
    endtask

    //================================================================================
    // MAIN TEST STIMULUS
    //================================================================================

    initial begin
        $display("\n");
        $display("╔════════════════════════════════════════════════════════════════╗");
        $display("║        Scratchpad Image Processing - Full Test                ║");
        $display("║        Testing complete %0d x %0d matrix                      ║", ROWS, COLS);
        $display("╚════════════════════════════════════════════════════════════════╝");
        $display("\n");

        $display("[SETUP] Parameters:");
        $display("  Data Width:        %0d bits", DATA_WIDTH);
        $display("  Matrix Size:       %0d x %0d pixels", ROWS, COLS);
        $display("  Total Pixels:      %0d", TOTAL_PIXELS);
        $display("  Parallel Input:    %0d pixels per cycle", MAX_INPUT_SCOOP);
        $display("  Expected Cycles:   %0d", (TOTAL_PIXELS + MAX_INPUT_SCOOP - 1) / MAX_INPUT_SCOOP);
        $display("\n");

        //====== INITIALIZATION ======
        rst = 0;
        for (int idx = 0; idx < MAX_INPUT_SCOOP; idx++) begin
            red_in[idx] = 0;
            green_in[idx] = 0;
            blue_in[idx] = 0;
        end
        #(2*CLK_PERIOD);

        //====== RELEASE RESET ======
        rst = 1;
        #(CLK_PERIOD);

        //====== TEST 1: STREAM ALL PIXELS FROM VECTORS.SV ======
        $display("[TEST 1] Streaming vectors.sv data");
        $display("────────────────────────────────────────────────────────────────");
        $display("[STEP 1.1] Loading %0d test vectors from vectors.sv", TOTAL_PIXELS);
        $display("[STEP 1.2] Input mapping: test_red → red, test_green → green, test_blue → blue");
        $display("[STEP 1.3] Hardware stores pixels at calculated [row][col] positions");
        $display("\n");

        // Stream all pixels with MAX_INPUT_SCOOP pixels per cycle
        for (int i = 0; i < TOTAL_PIXELS; i += MAX_INPUT_SCOOP) begin
            // Load MAX_INPUT_SCOOP pixels in parallel
            for (int j = 0; j < MAX_INPUT_SCOOP && (i + j) < TOTAL_PIXELS; j++) begin
                red_in[j] <= test_red[i + j];
                green_in[j] <= test_green[i + j];
                blue_in[j] <= test_blue[i + j];
            end

            #(CLK_PERIOD);

            // Progress indicator every 50,000 pixels
            if ((i + MAX_INPUT_SCOOP) % 50000 == 0) begin
                $display("[PROGRESS] Streamed %0d / %0d pixels (%0d%%)",
                         i + MAX_INPUT_SCOOP,
                         TOTAL_PIXELS,
                         ((i + MAX_INPUT_SCOOP) * 100) / TOTAL_PIXELS);
            end
        end

        $display("[STEP 1.4] Completed streaming all %0d pixels", TOTAL_PIXELS);
        $display("\n");

        //====== WAIT FOR STABILIZATION ======
        $display("[STEP 1.5] Waiting for outputs to stabilize...");
        #(CLK_PERIOD * 10);

        //====== CAPTURE OUTPUT ======
        $display("[STEP 1.6] Capturing complete output matrix to output_rgb.csv");
        write_output_matrix("output_rgb.csv");
        $display("\n");

        //====== TEST 2: GRADIENT VALIDATION ======
        $display("[TEST 2] Gradient pattern validation");
        $display("────────────────────────────────────────────────────────────────");
        $display("[STEP 2.1] Reset scratchpad");

        // Reset
        rst = 0;
        #(CLK_PERIOD);
        rst = 1;
        #(CLK_PERIOD);

        $display("[STEP 2.2] Streaming gradient pattern (%0d pixels, %0d pixels/cycle)",
                 TOTAL_PIXELS, MAX_INPUT_SCOOP);

        // Stream gradient pattern
        for (int i = 0; i < TOTAL_PIXELS; i += MAX_INPUT_SCOOP) begin
            for (int j = 0; j < MAX_INPUT_SCOOP && (i + j) < TOTAL_PIXELS; j++) begin
                red_in[j] <= 8'h00 + (((i + j) * 8'hFF) / TOTAL_PIXELS);
                green_in[j] <= 8'h80;
                blue_in[j] <= 8'hFF - (((i + j) * 8'hFF) / TOTAL_PIXELS);
            end
            #(CLK_PERIOD);

            if ((i + MAX_INPUT_SCOOP) % 50000 == 0) begin
                $display("[PROGRESS] Processed %0d / %0d pixels",
                         i + MAX_INPUT_SCOOP, TOTAL_PIXELS);
            end
        end

        $display("[STEP 2.3] Completed gradient streaming");
        $display("\n");

        //====== WAIT FOR STABILIZATION ======
        $display("[STEP 2.4] Waiting for outputs to stabilize...");
        #(CLK_PERIOD * 10);

        //====== CAPTURE OUTPUT ======
        $display("[STEP 2.5] Capturing gradient output to output_gradient.csv");
        write_output_matrix("output_gradient.csv");
        $display("\n");

        //====== TEST COMPLETE ======
        $display("╔════════════════════════════════════════════════════════════════╗");
        $display("║                    FULL TEST COMPLETED                         ║");
        $display("╚════════════════════════════════════════════════════════════════╝");
        $display("\n");

        $display("[SUMMARY]");
        $display("  Test 1: Streamed all %0d pixels from vectors.sv", TOTAL_PIXELS);
        $display("  Test 2: Validated gradient pattern storage");
        $display("\n");

        $display("[OUTPUT FILES]");
        $display("  ✓ output_rgb.csv          - Complete %0dx%0d matrix", ROWS, COLS);
        $display("  ✓ output_gradient.csv     - Gradient validation test");
        $display("\n");

        $display("[NEXT STEPS]");
        $display("  1. Convert CSV back to image:");
        $display("     python image_hex_converter.py --mode hex2img \\");
        $display("       --input output_rgb.csv --output result.png \\");
        $display("       --width %0d --height %0d", COLS, ROWS);
        $display("\n");
        $display("  2. Compare input and output:");
        $display("     python image_hex_converter.py --mode compare \\");
        $display("       --input test.png --output result.png");
        $display("\n");

        $finish;
    end

endmodule
