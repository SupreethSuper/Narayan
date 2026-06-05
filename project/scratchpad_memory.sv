`include "nar_params.vh"

module scratchpad_memory #(
    parameter DATA_WIDTH      = NAR_NUM_BITS,
    parameter ROWS            = NAR_MAT_ROWS,
    parameter COLS            = NAR_MAT_COLS,
    parameter MAX_INPUT_SCOOP = NAR_MAX_INPUT_SCOOP,
    parameter MEM_ADDRESS     = $clog2(NAR_MAT_ROWS * NAR_MAT_COLS)
)
(
    input  logic clk,      // Clock
    input  logic rw_,      // 0 = Write, 1 = Read
    input  logic cs,        // chip select
    input  logic rst,       // reset

    input  logic [MEM_ADDRESS-1:0] wr_addr,

    input  logic [DATA_WIDTH-1:0] data_in,

    output logic [DATA_WIDTH-1:0] data_out
);

    localparam DEPTH = ROWS * COLS;

    //definitions of ZERO and ONE
    localparam logic [DATA_WIDTH-1:0] MEM_ZERO = {DATA_WIDTH{1'b0}};
    localparam logic [DATA_WIDTH-1:0] MEM_ONE = {DATA_WIDTH{1'b1}};




    logic [DATA_WIDTH-1:0] memory [0:DEPTH-1];



    always_ff @(posedge clk or posedge cs or negedge rst) begin : ram_unit
    
    if(!cs || !rst) begin
        data_out <= MEM_ZERO;
    end

    else begin
        case (rw_)

            1'b0:
            begin
                memory[wr_addr] <= data_in;
            end

            1'b1:
            begin
                data_out <= memory[wr_addr];
            end

            default:
            begin
                data_out <= MEM_ONE;
            end

        endcase
    end

    end

endmodule


