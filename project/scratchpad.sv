`include "nar_params.vh"

module scratchpad #(
    parameter DATA_WIDTH      = NAR_NUM_BITS,
    parameter ROWS            = NAR_MAT_ROWS,
    parameter COLS            = NAR_MAT_COLS,
    parameter MAX_INPUT_SCOOP = NAR_MAX_INPUT_SCOOP,
    parameter MEM_ADDRESS     = $clog2(NAR_MAT_ROWS*NAR_MAT_COLS)
)

(
    input logic clk,             //clock
    input logic rw_,             //read write enable.  0 for write, 1 for read
    input logic [MEM_ADDRESS-1:0] wr_addr,  //write address
    input logic [DATA_WIDTH*MAX_INPUT_SCOOP-1:0] data_in,  //data to be written
    output logic [DATA_WIDTH*MAX_INPUT_SCOOP-1:0] data_out  //data to be read
);


    logic valid;
    logic [MEM_ADDRESS - 1 : 0] memory [DATA_WIDTH * MAX_INPUT_SCOOP - 1 : 0];

    always_ff @( posedge clk) begin : ram_unit


        begin
            case(rw_)
                1'b0 : begin
                    memory[wr_addr] <= data_in;
                end
                1'b1 : begin
                    data_out <= memory[wr_addr];
                end  
            endcase
        end
    end


    

endmodule
