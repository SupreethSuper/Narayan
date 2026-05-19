`include "nar_params.vh"

module scratchpad #(
    parameter DATA_WIDTH = NAR_NUM_BITS,
    parameter ROWS       = NAR_MAT_ROWS,
    parameter COLS       = NAR_MAT_COLS
)

(
    input logic  clk,
    input logic  rst,
    input logic  [DATA_WIDTH-1:0] data_in,
    output logic [DATA_WIDTH-1:0] data_out
);

    always_ff @(posedge clk or negedge rst)
    begin
        if(~rst)
            data_out <= 0;
        else
            data_out <= data_in;
    end

endmodule