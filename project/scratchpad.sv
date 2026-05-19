`include "nar_params.vh"

module scratchpad #(
    parameter DATA_WIDTH = NAR_NUM_BITS,
    parameter ROWS       = NAR_MAT_ROWS,
    parameter COLS       = NAR_MAT_COLS
)

(
    input logic  clk,
    input logic  rst,
    input logic  [DATA_WIDTH-1:0] red,
    input logic  [DATA_WIDTH-1:0] green,
    input logic  [DATA_WIDTH-1:0] blue,
    output logic [DATA_WIDTH-1:0] red_out,
    output logic [DATA_WIDTH-1:0] green_out,
    output logic [DATA_WIDTH-1:0] blue_out
);

    always_ff @(posedge clk or negedge rst)
    begin
        if(~rst)
        begin
            red_out <= 0;
            green_out <= 0;
            blue_out <= 0;
        end
        else
        begin
            red_out <= red;
            green_out <= green;
            blue_out <= blue;
        end
    end

endmodule