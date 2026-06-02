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

    // Flattened parallel input interface (multiple pixels per cycle)
    input logic  [DATA_WIDTH*MAX_INPUT_SCOOP-1:0] red  ,
    input logic  [DATA_WIDTH*MAX_INPUT_SCOOP-1:0] green,
    input logic  [DATA_WIDTH*MAX_INPUT_SCOOP-1:0] blue ,

    // Flattened output interface
    output logic [ROWS*COLS*DATA_WIDTH-1:0] red_out   ,
    output logic [ROWS*COLS*DATA_WIDTH-1:0] green_out ,
    output logic [ROWS*COLS*DATA_WIDTH-1:0] blue_out
);

    //================================================================================
    // LOCAL PARAMETERS
    //================================================================================

    localparam TOTAL_PIXELS = ROWS * COLS;
    localparam PIXEL_ADDR_WIDTH = $clog2(TOTAL_PIXELS);

    //================================================================================
    // INTERNAL STORAGE (2D arrays - later flattened to outputs)
    //================================================================================

    logic [DATA_WIDTH-1:0] red_pad   [0:ROWS-1][0:COLS-1];
    logic [DATA_WIDTH-1:0] green_pad [0:ROWS-1][0:COLS-1];
    logic [DATA_WIDTH-1:0] blue_pad  [0:ROWS-1][0:COLS-1];

    // INTERNAL PIXEL COUNTER (auto-increments, wraps around when full)
    logic [PIXEL_ADDR_WIDTH-1:0] pixel_counter;

    // VALIDITY FLAG (indicates when outputs are ready)
    logic valid;

    //================================================================================
    // COMBINATIONAL: FLATTEN 2D STORAGE ARRAYS TO FLAT OUTPUT VECTORS
    //================================================================================
    // Generate blocks unroll all 2D → 1D mappings at synthesis time
    //================================================================================

    generate
        for (genvar row = 0; row < ROWS; row++) begin : output_row_gen
            for (genvar col = 0; col < COLS; col++) begin : output_col_gen
                assign red_out[(row*COLS+col+1)*DATA_WIDTH-1 -: DATA_WIDTH]   = red_pad[row][col];
                assign green_out[(row*COLS+col+1)*DATA_WIDTH-1 -: DATA_WIDTH] = green_pad[row][col];
                assign blue_out[(row*COLS+col+1)*DATA_WIDTH-1 -: DATA_WIDTH]  = blue_pad[row][col];
            end
        end
    endgenerate

    //================================================================================
    // SEQUENTIAL: PIXEL STORAGE WITH AUTO-INCREMENT COUNTER
    //================================================================================
    // Unroll MAX_INPUT_SCOOP parallel pixel stores (synthesizer unrolls the loop)
    // Each cycle processes one batch of MAX_INPUT_SCOOP pixels in parallel
    //================================================================================

    logic [PIXEL_ADDR_WIDTH-1:0] stored_index;
    logic signed [31:0] stored_row;
    logic signed [31:0] stored_col;

    always_ff @(posedge clk or negedge rst)
    begin
        if(~rst)
        begin
            // Reset: Only reset essential control signals (low fanout)
            pixel_counter <= '0;
            valid         <= 1'b0;
        end
        else
        begin
            // Mark outputs as valid after reset is released
            valid <= 1'b1;

            // Unroll: MAX_INPUT_SCOOP parallel pixel stores
            for (int scoop_idx = 0; scoop_idx < MAX_INPUT_SCOOP; scoop_idx++)
            begin
                // Calculate linear index for this pixel
                stored_index = pixel_counter + scoop_idx;

                // Convert linear index to 2D coordinates
                stored_row = (stored_index < TOTAL_PIXELS) ? (stored_index / COLS) : 0;
                stored_col = (stored_index < TOTAL_PIXELS) ? (stored_index % COLS) : 0;

                // Store pixel only if within bounds
                if (stored_index < TOTAL_PIXELS)
                begin
                    red_pad[stored_row][stored_col]   <= red[(scoop_idx+1)*DATA_WIDTH-1 -: DATA_WIDTH];
                    green_pad[stored_row][stored_col] <= green[(scoop_idx+1)*DATA_WIDTH-1 -: DATA_WIDTH];
                    blue_pad[stored_row][stored_col]  <= blue[(scoop_idx+1)*DATA_WIDTH-1 -: DATA_WIDTH];
                end
            end

            // Auto-increment pixel counter for next cycle
            if (pixel_counter + MAX_INPUT_SCOOP < TOTAL_PIXELS)
                pixel_counter <= pixel_counter + MAX_INPUT_SCOOP;
            else
                pixel_counter <= '0;  // Wrap around when complete
        end
    end

endmodule
