`include "nar_params.vh"

module scratchpad #(
    parameter DATA_WIDTH      = NAR_NUM_BITS,
    parameter ROWS            = NAR_MAT_ROWS,
    parameter COLS            = NAR_MAT_COLS,
    parameter MAX_INPUT_SCOOP = NAR_MAX_INPUT_SCOOP
)

(
    input logic  clk,
    input logic  rst,

    // Parallel input interface (multiple pixels per cycle)
    input logic  [DATA_WIDTH-1:0] red   [0:MAX_INPUT_SCOOP-1],
    input logic  [DATA_WIDTH-1:0] green [0:MAX_INPUT_SCOOP-1],
    input logic  [DATA_WIDTH-1:0] blue  [0:MAX_INPUT_SCOOP-1],

    output logic [DATA_WIDTH-1:0] red_out   [0:ROWS-1][0:COLS-1],
    output logic [DATA_WIDTH-1:0] green_out [0:ROWS-1][0:COLS-1],
    output logic [DATA_WIDTH-1:0] blue_out  [0:ROWS-1][0:COLS-1]
);

    //================================================================================
    // LOCAL PARAMETERS
    //================================================================================

    localparam TOTAL_PIXELS = ROWS * COLS;
    localparam PIXEL_ADDR_WIDTH = $clog2(TOTAL_PIXELS);

    // DEPRECATED: localparam REGION_ROWS = ROWS / MAX_INPUT_SCOOP;
    // Reason: Region-based approach broadcasts to entire regions, losing intermediate
    //         pixel data. Each cycle overwrites previous values. Only final state survives.
    //         Replaced with sequential storage using internal pixel counter.

    //================================================================================
    // INTERNAL SIGNALS (all using 'logic' - let compiler decide best implementation)
    //================================================================================

    logic [DATA_WIDTH-1:0] red_pad   [0:ROWS-1][0:COLS-1];
    logic [DATA_WIDTH-1:0] green_pad [0:ROWS-1][0:COLS-1];
    logic [DATA_WIDTH-1:0] blue_pad  [0:ROWS-1][0:COLS-1];

    // INTERNAL PIXEL COUNTER (no input pin needed)
    // Manages itself: auto-increments each cycle, wraps around when full
    logic [PIXEL_ADDR_WIDTH-1:0] pixel_counter;

    assign red_out   = red_pad;
    assign green_out = green_pad;
    assign blue_out  = blue_pad;

    //================================================================================
    // INITIALIZATION
    //================================================================================

    // initial begin
    //     red_pad   <= '{default:0};
    //     green_pad <= '{default:0};
    //     blue_pad  <= '{default:0};
    //     pixel_counter <= 0;
    // end

    //================================================================================
    // SEQUENTIAL STORAGE WITH AUTO-INCREMENT (NEW IMPLEMENTATION)
    //================================================================================
    // This approach:
    // 1. Maintains internal pixel_counter (no external input needed)
    // 2. Converts linear pixel_counter to 2D [row][col] address
    // 3. Stores each pixel at its calculated position (no overwriting)
    // 4. Preserves all 250,000 pixels in the matrix
    // 5. Auto-increments counter by MAX_INPUT_SCOOP each cycle
    //================================================================================

    always_ff @(posedge clk or negedge rst)
    begin
        if(~rst)
        begin
            // Reset all storage to zeros
            pixel_counter <= '{default:0};
            red_pad       <= '{default:0};
            green_pad     <= '{default:0};
            blue_pad      <= '{default:0};
        end


        else
        begin
            // Store MAX_INPUT_SCOOP pixels in parallel at their calculated positions
            for (int scoop_idx = 0; scoop_idx < MAX_INPUT_SCOOP; scoop_idx++)
            begin
                logic [PIXEL_ADDR_WIDTH-1:0] stored_index;
                int stored_row;
                int stored_col;

                // Calculate linear index for this pixel
                stored_index = pixel_counter + scoop_idx;

                // Convert linear index to 2D coordinates
                // row = index / COLS
                // col = index % COLS
                stored_row = stored_index / COLS;
                stored_col = stored_index % COLS;

                // Store pixel only if within bounds
                if (stored_index < TOTAL_PIXELS)
                begin
                    red_pad[stored_row][stored_col]   <= red[scoop_idx];
                    green_pad[stored_row][stored_col] <= green[scoop_idx];
                    blue_pad[stored_row][stored_col]  <= blue[scoop_idx];
                end
            end

            // Auto-increment pixel counter for next cycle
            // This is INTERNAL logic - testbench doesn't need to track it!
            if (pixel_counter + MAX_INPUT_SCOOP < TOTAL_PIXELS)
                pixel_counter <= pixel_counter + MAX_INPUT_SCOOP;
            else
                pixel_counter <= 0;  // Wrap around when complete
        end
    end

    //================================================================================
    // DEPRECATED: REGION-BASED BROADCAST (OLD IMPLEMENTATION - COMMENTED OUT)
    //================================================================================
    // The following code was the original implementation that broadcast pixels to
    // regions. It is REPLACED by the sequential storage logic above.
    //
    // REASON FOR DEPRECATION:
    // - Broadcast-to-regions overwrites all pixels in a region every cycle
    // - Only the FINAL pixel value survives in each region
    // - 250,000 input pixels collapsed to 3 final values (one per region)
    // - Result: Data loss, only last broadcast state preserved
    // - Output: Solid color image instead of preserving gradient
    //
    // OLD CODE (for reference/history):
    //
    // always_ff @(posedge clk or negedge rst)
    // begin
    //     if(~rst)
    //     begin
    //         for (int i = 0; i < ROWS; i++)
    //             for (int j = 0; j < COLS; j++)
    //             begin
    //                 red_pad[i][j]   <= 0;
    //                 green_pad[i][j] <= 0;
    //                 blue_pad[i][j]  <= 0;
    //             end
    //     end
    //     else
    //     begin
    //         // PROBLEM: This broadcasts same value to entire region every cycle!
    //         for (int scoop_idx = 0; scoop_idx < MAX_INPUT_SCOOP; scoop_idx++)
    //         begin
    //             int row_start = scoop_idx * REGION_ROWS;
    //             int row_end   = (scoop_idx + 1) * REGION_ROWS;
    //
    //             for (int i = row_start; i < row_end; i++)
    //             begin
    //                 for (int j = 0; j < COLS; j++)
    //                 begin
    //                     red_pad[i][j]   <= red[scoop_idx];    // ← OVERWRITES!
    //                     green_pad[i][j] <= green[scoop_idx];
    //                     blue_pad[i][j]  <= blue[scoop_idx];
    //                 end
    //             end
    //         end
    //     end
    // end
    //
    // COMPARISON:
    // OLD (Region-based broadcast):
    //   - Cycle 0: Region 0 ← 0x00, Region 1 ← 0x00, Region 2 ← 0x01
    //   - Cycle 1: Region 0 ← 0x01 (overwrites!), Region 1 ← 0x01, Region 2 ← 0x02
    //   - ...
    //   - Result: Only final values remain
    //
    // NEW (Sequential storage):
    //   - Pixel 0 → [0][0], Pixel 1 → [0][1], Pixel 2 → [0][2]
    //   - Pixel 500 → [1][0], Pixel 501 → [1][1], etc.
    //   - Result: All 250,000 pixels preserved at their calculated positions
    //
    //================================================================================

endmodule
