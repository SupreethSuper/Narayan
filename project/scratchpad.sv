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
    input logic  rw_,       // 0 = Write, 1 = Read

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
    // INTERNAL STORAGE: RAM-BASED (Linear memory arrays)
    //================================================================================

    // Three separate RAMs for RGB channels (one address, parallel write/read)
    logic [DATA_WIDTH-1:0] red_ram   [0:TOTAL_PIXELS-1];
    logic [DATA_WIDTH-1:0] green_ram [0:TOTAL_PIXELS-1];
    logic [DATA_WIDTH-1:0] blue_ram  [0:TOTAL_PIXELS-1];

    // INTERNAL PIXEL COUNTER (auto-increments during write, wraps when full)
    logic [PIXEL_ADDR_WIDTH-1:0] pixel_address;


    // VALIDITY FLAG (indicates when outputs are ready)
    logic valid;

    //================================================================================
    // COMBINATIONAL: READ ALL RAM CONTENTS TO FLAT OUTPUT VECTORS
    //================================================================================
    // Generate blocks unroll all RAM reads at synthesis time
    // Each pixel in RAM is mapped to its position in the flat output vector
    //================================================================================

    // generate
    //     for (genvar idx = 0; idx < TOTAL_PIXELS; idx++) begin : output_gen
    //         assign red_out[(idx+1)*DATA_WIDTH-1 -: DATA_WIDTH]   = red_ram[idx];
    //         assign green_out[(idx+1)*DATA_WIDTH-1 -: DATA_WIDTH] = green_ram[idx];
    //         assign blue_out[(idx+1)*DATA_WIDTH-1 -: DATA_WIDTH]  = blue_ram[idx];
    //     end
    // endgenerate

    //================================================================================
    // SEQUENTIAL: RAM WRITE WITH AUTO-INCREMENT COUNTER
    //================================================================================
    // Store MAX_INPUT_SCOOP pixels per cycle into RAM at consecutive addresses
    // Counter auto-increments after each write, wraps around when full
    //================================================================================

    logic [PIXEL_ADDR_WIDTH-1:0] write_addr;

    always_ff @(posedge clk or negedge rst) begin : writer
        if(~rst) begin
            pixel_address <= '0;
            valid         <= 1'b0;
        end
        else begin
            valid <= 1'b1;
            
            if (~rw_)
                pixel_address <= pixel_address + 1;
            
            red_ram[pixel_address]   <= red;
            green_ram[pixel_address] <= green;
            blue_ram[pixel_address]  <= blue;
            
        end
    end

endmodule
